"""Worker ModbusWorker — Vòng lặp Polling cảm biến Modbus RTU.

Chạy trên QThread riêng biệt, giao tiếp với DashboardController qua Qt Signals.
Hỗ trợ reconnect tự động với exponential backoff khi mất kết nối.
"""

import inspect
import logging
import time
from datetime import datetime

from PySide6.QtCore import QObject, Signal

from pymodbus.client import ModbusSerialClient
from pymodbus.exceptions import ModbusIOException

from core.formula import apply_formula

logger = logging.getLogger("datalogger.modbus")

_BACKOFF_INITIAL = 1.0
_BACKOFF_MAX = 30.0
_BACKOFF_FACTOR = 2.0


class ModbusWorker(QObject):
    """Worker đọc dữ liệu Modbus từ cảm biến qua RS485.

    Signals:
        data_ready(dict): payload = {sensor_id, raw_value, value, recorded_at,
                          is_alarm, alarm_type, di_states}
        modbus_error(str): Lỗi Timeout/CRC/kết nối.
        connection_changed(bool): True khi kết nối thành công, False khi mất.
        alarm_changed(dict): {sensor_id, is_alarm, alarm_type} — alarm state transition.
        worker_stopped(): Worker đã dừng hoàn toàn.
    """

    data_ready = Signal(dict)
    modbus_error = Signal(str)
    connection_changed = Signal(bool)
    alarm_changed = Signal(dict)
    worker_stopped = Signal()
    heartbeat = Signal(str)

    def __init__(
        self,
        port: str = "/dev/ttyUSB0",
        baudrate: int = 9600,
        bytesize: int = 8,
        parity: str = "N",
        stopbits: int = 1,
        timeout: int = 1,
        poll_interval: int = 5,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        
        try:
            import tomllib
            from core._paths import CONFIG_DIR
            config_file = CONFIG_DIR / "config.toml"
            if config_file.exists():
                with open(config_file, "rb") as f:
                    cfg = tomllib.load(f)
                    if "modbus" in cfg and "POLLING_INTERVAL" in cfg["modbus"]:
                        poll_interval = cfg["modbus"]["POLLING_INTERVAL"]
        except Exception:
            pass

        self._port = port
        self._baudrate = baudrate
        self._bytesize = bytesize
        self._parity = parity
        self._stopbits = stopbits
        self._timeout = timeout
        self._poll_interval = max(1, poll_interval)
        self._is_running = False
        self._client: ModbusSerialClient | None = None
        self._sensors: list[dict] = []
        # Digital I/O config: {sensor_id: [list of io dicts]}
        self._digital_ios: dict[int, list[dict]] = {}
        # Alarm state tracking: {sensor_id: bool}
        self._alarm_states: dict[int, bool] = {}
        self._do_states: dict[int, bool] = {}  # sensor_id -> current DO boolean state

    def set_sensors(self, sensors: list[dict]) -> None:
        self._sensors = sensors
        logger.info("Updated sensor list: %d sensors", len(sensors))

    def set_digital_ios(self, digital_ios: dict[int, list[dict]]) -> None:
        """Set DI/DO configuration grouped by sensor_id."""
        self._digital_ios = digital_ios
        total = sum(len(v) for v in digital_ios.values())
        logger.info("Digital I/O configured: %d channels across %d sensors", total, len(digital_ios))

    def write_single_coil(self, sensor_id: int, value: bool) -> None:
        """Write a coil value for a Standalone DO sensor (manual control from UI).

        Looks up the sensor config by id, then writes to its register_address.
        Thread-safe: called from main thread but runs in ModbusWorker thread context.
        """
        if not self._client or not self._client.connected:
            logger.warning("write_single_coil: client not connected")
            return

        sensor_cfg = None
        for s in self._sensors:
            if s["id"] == sensor_id:
                sensor_cfg = s
                break
        if sensor_cfg is None:
            logger.warning("write_single_coil: sensor_id %d not found", sensor_id)
            return

        try:
            kw = self._slave_kwarg("write_coil", sensor_cfg["slave_id"])
            result = self._client.write_coil(
                address=sensor_cfg["register_address"], value=value, **kw
            )
            if result.isError():
                logger.warning(
                    "Manual DO write error: id=%d addr=%d value=%s",
                    sensor_id, sensor_cfg["register_address"], value,
                )
            else:
                logger.info(
                    "Manual DO %s: id=%d addr=%d",
                    "ON" if value else "OFF",
                    sensor_id, sensor_cfg["register_address"],
                )
                self._do_states[sensor_id] = value
                # Emit data_ready so the UI card updates immediately
                self.data_ready.emit({
                    "sensor_id": sensor_id,
                    "raw_value": 1 if value else 0,
                    "value": 1 if value else 0,
                    "status": "ON" if value else "OFF",
                    "recorded_at": datetime.now().isoformat(),
                    "is_alarm": False,
                    "alarm_type": "",
                    "di_states": [],
                })
        except Exception as e:
            logger.error("Manual DO write exception: id=%d err=%s", sensor_id, e)

    def run(self) -> None:
        """Vòng lặp chính — được gọi khi QThread.start()."""
        self._is_running = True

        try:
            if not self._try_connect():
                return

            backoff = _BACKOFF_INITIAL
            now = time.monotonic()
            next_poll: dict[int, float] = {
                s["id"]: now for s in self._sensors
            }

            last_heartbeat = time.monotonic()
            
            while self._is_running:
                now = time.monotonic()
                if now - last_heartbeat >= 5.0:
                    self.heartbeat.emit("ModbusWorker")
                    last_heartbeat = now

                if not self._client or not self._client.connected:
                    self.connection_changed.emit(False)
                    self.modbus_error.emit(f"Connection lost {self._port}, retrying in {backoff:.0f}s...")
                    time.sleep(backoff)
                    backoff = min(backoff * _BACKOFF_FACTOR, _BACKOFF_MAX)

                    if not self._is_running:
                        break
                    if self._try_connect():
                        backoff = _BACKOFF_INITIAL
                        now = time.monotonic()
                        for s in self._sensors:
                            next_poll[s["id"]] = now
                    continue

                now = time.monotonic()
                polled_any = False
                for sensor_cfg in self._sensors:
                    if not self._is_running:
                        break
                    sid = sensor_cfg["id"]
                    if now >= next_poll.get(sid, 0):
                        self._poll_single(sensor_cfg)
                        interval = sensor_cfg.get("poll_interval", self._poll_interval)
                        next_poll[sid] = time.monotonic() + max(1, interval)
                        polled_any = True

                if not polled_any:
                    time.sleep(self._poll_interval)
                else:
                    time.sleep(self._poll_interval)

            if self._client:
                self._client.close()
            logger.info("ModbusWorker stopped.")
        except Exception as e:
            logger.critical("ModbusWorker crashed: %s", e, exc_info=True)
        finally:
            self._is_running = False
            self.worker_stopped.emit()

    def stop(self) -> None:
        self._is_running = False

    def _try_connect(self) -> bool:
        """Thử kết nối, trả về True nếu thành công."""
        try:
            if self._client:
                self._client.close()
        except Exception:
            pass

        self._client = ModbusSerialClient(
            port=self._port,
            baudrate=self._baudrate,
            bytesize=self._bytesize,
            parity=self._parity,
            stopbits=self._stopbits,
            timeout=self._timeout,
        )

        if self._client.connect():
            logger.info("Modbus connected successfully: %s @ %d baud", self._port, self._baudrate)
            self.connection_changed.emit(True)
            return True

        self.modbus_error.emit(f"Could not connect to port {self._port}")
        self.connection_changed.emit(False)
        self._is_running = False
        return False

    def _poll_single(self, sensor_cfg: dict) -> None:
        sensor_type = sensor_cfg.get("sensor_type", "ANALOG")

        # Route to specialised handlers based on sensor_type
        if sensor_type == "DI":
            self._poll_standalone_di(sensor_cfg)
        elif sensor_type == "DO":
            self._poll_standalone_do(sensor_cfg)
        else:
            self._poll_analog(sensor_cfg)

    # ── Analog Sensor Polling ──────────────────────────────────────────────

    def _poll_analog(self, sensor_cfg: dict) -> None:
        """Poll an ANALOG sensor: read value, check alarms, read child DIs, drive child DOs."""
        sensor_id = sensor_cfg["id"]
        slave_id = sensor_cfg["slave_id"]
        register_address = sensor_cfg["register_address"]
        register_type = sensor_cfg.get("register_type", "holding")
        data_type = sensor_cfg.get("data_type", "int16")
        data_format = sensor_cfg.get("data_format", "AB")
        coefficient_json = sensor_cfg.get("coefficient", "{}")

        try:
            raw_value = self._read_register(
                slave_id=slave_id,
                address=register_address,
                register_type=register_type,
                data_type=data_type,
                data_format=data_format,
            )

            if raw_value is None:
                return

            value = apply_formula(raw_value, coefficient_json)

            # --- Alarm threshold check ---
            is_alarm = False
            alarm_type = ""  # "min", "max", or "min+max"
            min_th = sensor_cfg.get("min_threshold")
            max_th = sensor_cfg.get("max_threshold")

            if min_th is not None and value <= min_th:
                is_alarm = True
                alarm_type = "min"
            if max_th is not None and value >= max_th:
                is_alarm = True
                alarm_type = "max" if not alarm_type else "min+max"

            prev_alarm = self._alarm_states.get(sensor_id, False)
            if is_alarm != prev_alarm:
                self._alarm_states[sensor_id] = is_alarm
                self.alarm_changed.emit({
                    "sensor_id": sensor_id,
                    "is_alarm": is_alarm,
                    "alarm_type": alarm_type,
                })
                # Drive attached DO relays on alarm state transition
                self._drive_do_relays(sensor_id, is_alarm, alarm_type)

            # --- Read attached DI states ---
            di_states = self._read_di_states(sensor_id)

            # --- Read attached DO states ---
            ios = self._digital_ios.get(sensor_id, [])
            do_channels = [io for io in ios if io.get("io_type") == "DO" and io.get("active", True)]
            do_states = []
            for ch in do_channels:
                do_states.append({
                    "id": ch["id"],
                    "state": self._do_states.get(ch["id"], False)
                })

            # --- Status code resolution (priority: 02 > 03 > 01) ---
            current_status = "00"
            for di in di_states:
                if di.get("state") is True:
                    dt = di.get("di_type")
                    if dt:
                        if dt == "02":
                            current_status = "02"
                            break  # Highest priority — stop immediately
                        elif dt == "03" and current_status not in ["02"]:
                            current_status = "03"
                        elif dt == "01" and current_status not in ["02", "03"]:
                            current_status = "01"
                        elif current_status == "00":  # Handle custom status
                            current_status = dt

            payload = {
                "sensor_id": sensor_id,
                "raw_value": raw_value,
                "value": round(value, 4),
                "status": current_status,
                "recorded_at": datetime.now().isoformat(),
                "is_alarm": is_alarm,
                "alarm_type": alarm_type,
                "di_states": di_states,
                "do_states": do_states,
            }

            self.data_ready.emit(payload)
            logger.debug(
                "Sensor %d (slave %d): raw=%s → value=%.4f alarm=%s",
                sensor_id, slave_id, raw_value, value, is_alarm,
            )

        except ModbusIOException as e:
            error_msg = f"Modbus I/O Error — Sensor ID {sensor_id} (slave {slave_id}): {e}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)

        except Exception as e:
            error_msg = f"Unknown error — Sensor ID {sensor_id}: {e}"
            logger.error(error_msg, exc_info=True)
            self.modbus_error.emit(error_msg)

    # ── Standalone DI Polling ──────────────────────────────────────────────

    def _poll_standalone_di(self, sensor_cfg: dict) -> None:
        """Poll a system-wide Standalone DI: read discrete input, emit status payload."""
        sensor_id = sensor_cfg["id"]
        slave_id = sensor_cfg["slave_id"]
        address = sensor_cfg["register_address"]

        try:
            kw = self._slave_kwarg("read_discrete_inputs", slave_id)
            resp = self._client.read_discrete_inputs(address=address, count=1, **kw)
            if resp.isError():
                self.modbus_error.emit(
                    f"Standalone DI read error: id={sensor_id} slave={slave_id} addr={address}"
                )
                return

            state = resp.bits[0]
            # Standalone DI has no link context — status is always "00"
            status = "00"

            payload = {
                "sensor_id": sensor_id,
                "raw_value": 1 if state else 0,
                "value": 1 if state else 0,
                "status": status,
                "recorded_at": datetime.now().isoformat(),
                "is_alarm": False,
                "alarm_type": "",
                "di_states": [],
            }
            self.data_ready.emit(payload)
            logger.debug("Standalone DI %d: state=%s status=%s", sensor_id, state, status)

        except Exception as e:
            error_msg = f"Standalone DI error — ID {sensor_id}: {e}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)

    def _poll_standalone_do(self, sensor_cfg: dict) -> None:
        """Poll a Standalone DO: read current coil state, emit payload.

        Standalone DOs share the same slave_id + address as attached DOs,
        so when alarm logic drives the relay, this read reflects the actual state.
        """
        sensor_id = sensor_cfg["id"]
        slave_id = sensor_cfg["slave_id"]
        address = sensor_cfg["register_address"]

        try:
            kw = self._slave_kwarg("read_coils", slave_id)
            resp = self._client.read_coils(address=address, count=1, **kw)
            if resp.isError():
                self.modbus_error.emit(
                    f"Standalone DO read error: id={sensor_id} slave={slave_id} addr={address}"
                )
                return

            state = resp.bits[0]
            self._do_states[sensor_id] = state

            payload = {
                "sensor_id": sensor_id,
                "raw_value": 1 if state else 0,
                "value": 1 if state else 0,
                "status": "ON" if state else "OFF",
                "recorded_at": datetime.now().isoformat(),
                "is_alarm": False,
                "alarm_type": "",
                "di_states": [],
            }
            self.data_ready.emit(payload)
            logger.debug("Standalone DO %d: state=%s", sensor_id, state)

        except Exception as e:
            error_msg = f"Standalone DO error — ID {sensor_id}: {e}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)

    def _slave_kwarg(self, func_name: str, slave_id: int) -> dict:
        """Detect correct keyword for slave/device_id across pymodbus versions."""
        try:
            sig = inspect.signature(getattr(self._client, func_name))
            if "device_id" in sig.parameters:
                return {"device_id": slave_id}
            if "slave" in sig.parameters:
                return {"slave": slave_id}
        except Exception:
            pass
        return {"slave": slave_id}

    def _read_register(
        self,
        slave_id: int,
        address: int,
        register_type: str,
        data_type: str,
        data_format: str,
    ) -> int | float | None:
        from core.modbus import _normalize_register_type
        norm_type = _normalize_register_type(register_type)

        count = 2 if data_type in ("float32", "int32", "uint32") else 1

        if norm_type == "Input Register":
            kw = self._slave_kwarg("read_input_registers", slave_id)
            result = self._client.read_input_registers(address=address, count=count, **kw)
        elif norm_type == "Holding Register":
            kw = self._slave_kwarg("read_holding_registers", slave_id)
            result = self._client.read_holding_registers(address=address, count=count, **kw)
        elif norm_type == "Discrete Input":
            kw = self._slave_kwarg("read_discrete_inputs", slave_id)
            result = self._client.read_discrete_inputs(address=address, count=count, **kw)
        elif norm_type == "Coil":
            kw = self._slave_kwarg("read_coils", slave_id)
            result = self._client.read_coils(address=address, count=count, **kw)
        else:
            # Fallback
            kw = self._slave_kwarg("read_holding_registers", slave_id)
            result = self._client.read_holding_registers(address=address, count=count, **kw)

        if result.isError():
            error_msg = f"Timeout slave_id={slave_id} register={address}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)
            return None

        # Xử lý các thanh ghi trả về kiểu Bool (Coil, Discrete Input)
        if norm_type in ("Coil", "Discrete Input"):
            if hasattr(result, "bits"):
                return 1 if result.bits[0] else 0
            return None

        # Xử lý các thanh ghi trả về list int (Holding, Input)
        if not hasattr(result, "registers"):
            return None

        # Dùng chung decode logic với Modbus Tester (single source of truth)
        from core.modbus import ModbusBase
        return ModbusBase.decode_data(result.registers, data_type, data_format)

    def _read_di_states(self, sensor_id: int) -> list[dict]:
        """Read all attached DI channels for an analog sensor.

        Returns list of {id, label, di_type, slave_id, register_address, state: bool}.
        """
        ios = self._digital_ios.get(sensor_id, [])
        di_channels = [io for io in ios if io.get("io_type") == "DI" and io.get("active", True)]
        if not di_channels or not self._client or not self._client.connected:
            return []

        results = []
        for ch in di_channels:
            addr = ch.get("address") or ch.get("register_address", 0)
            label = ch.get("label") or ch.get("name", "")
            try:
                kw = self._slave_kwarg("read_discrete_inputs", ch["slave_id"])
                resp = self._client.read_discrete_inputs(
                    address=addr, count=1, **kw
                )
                if resp.isError():
                    logger.warning(
                        "DI read error: sensor=%d slave=%d addr=%d",
                        sensor_id, ch["slave_id"], addr,
                    )
                    results.append({"id": ch["id"], "label": label, "di_type": ch.get("di_type"), "state": None})
                else:
                    results.append({"id": ch["id"], "label": label, "di_type": ch.get("di_type"), "state": resp.bits[0]})
            except Exception as e:
                logger.warning("DI read exception: %s", e)
                results.append({"id": ch["id"], "label": label, "di_type": ch.get("di_type"), "state": None})
        return results

    def _drive_do_relays(self, sensor_id: int, is_alarm: bool, alarm_type: str) -> None:
        """Write attached DO coils on alarm state transition.

        When alarm activates: set matching DO coils to ON.
        When alarm clears: set all DO coils for this sensor to OFF.
        """
        ios = self._digital_ios.get(sensor_id, [])
        do_channels = [io for io in ios if io.get("io_type") == "DO" and io.get("active", True)]
        if not do_channels or not self._client or not self._client.connected:
            return

        for ch in do_channels:
            addr = ch.get("address") or ch.get("register_address", 0)
            # Determine if this specific DO should fire
            if is_alarm:
                should_activate = False
                if ch.get("trigger_on_max", True) and "max" in alarm_type:
                    should_activate = True
                if ch.get("trigger_on_min", True) and "min" in alarm_type:
                    should_activate = True
                coil_value = should_activate
            else:
                # Alarm cleared → turn off all DO relays
                coil_value = False

            try:
                kw = self._slave_kwarg("write_coil", ch["slave_id"])
                result = self._client.write_coil(
                    address=addr, value=coil_value, **kw
                )
                if result.isError():
                    logger.warning(
                        "DO write error: sensor=%d slave=%d addr=%d value=%s",
                        sensor_id, ch["slave_id"], addr, coil_value,
                    )
                else:
                    logger.info(
                        "DO relay %s: sensor=%d slave=%d addr=%d → %s",
                        "ON" if coil_value else "OFF",
                        sensor_id, ch["slave_id"], addr, coil_value,
                    )
                    self._do_states[ch["id"]] = coil_value
            except Exception as e:
                logger.warning("DO write exception: sensor=%d err=%s", sensor_id, e)
