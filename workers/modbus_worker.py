"""Worker ModbusWorker — Vòng lặp Polling cảm biến Modbus RTU.

Chạy trên QThread riêng biệt, giao tiếp với DashboardController qua Qt Signals.
Hỗ trợ reconnect tự động với exponential backoff khi mất kết nối.
"""

import inspect
import logging
import struct
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
        data_ready(dict): payload = {sensor_id, raw_value, value, recorded_at}
        modbus_error(str): Lỗi Timeout/CRC/kết nối.
        connection_changed(bool): True khi kết nối thành công, False khi mất.
        worker_stopped(): Worker đã dừng hoàn toàn.
    """

    data_ready = Signal(dict)
    modbus_error = Signal(str)
    connection_changed = Signal(bool)
    worker_stopped = Signal()

    def __init__(
        self,
        port: str = "/dev/ttyUSB0",
        baudrate: int = 9600,
        bytesize: int = 8,
        parity: str = "N",
        stopbits: int = 1,
        timeout: int = 1,
        poll_interval: int = 3,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
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

    def set_sensors(self, sensors: list[dict]) -> None:
        self._sensors = sensors
        logger.info("Cập nhật danh sách cảm biến: %d sensors", len(sensors))

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

            while self._is_running:
                if not self._client or not self._client.connected:
                    self.connection_changed.emit(False)
                    self.modbus_error.emit(f"Mất kết nối {self._port}, thử lại sau {backoff:.0f}s...")
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
                    time.sleep(0.1)
                else:
                    time.sleep(0.05)

            if self._client:
                self._client.close()
            logger.info("ModbusWorker đã dừng.")
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
            logger.info("Kết nối Modbus thành công: %s @ %d baud", self._port, self._baudrate)
            self.connection_changed.emit(True)
            return True

        self.modbus_error.emit(f"Không thể kết nối cổng {self._port}")
        self.connection_changed.emit(False)
        self._is_running = False
        return False

    def _poll_single(self, sensor_cfg: dict) -> None:
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

            payload = {
                "sensor_id": sensor_id,
                "raw_value": raw_value,
                "value": round(value, 4),
                "recorded_at": datetime.now().isoformat(),
            }

            self.data_ready.emit(payload)
            logger.debug(
                "Sensor %d (slave %d): raw=%s → value=%.4f",
                sensor_id, slave_id, raw_value, value,
            )

        except ModbusIOException as e:
            error_msg = f"Modbus I/O Error — Sensor ID {sensor_id} (slave {slave_id}): {e}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)

        except Exception as e:
            error_msg = f"Lỗi không xác định — Sensor ID {sensor_id}: {e}"
            logger.error(error_msg, exc_info=True)
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
        count = 2 if data_type == "float32" else 1

        if register_type == "input":
            kw = self._slave_kwarg("read_input_registers", slave_id)
            result = self._client.read_input_registers(
                address=address, count=count, **kw
            )
        else:
            kw = self._slave_kwarg("read_holding_registers", slave_id)
            result = self._client.read_holding_registers(
                address=address, count=count, **kw
            )

        if result.isError():
            error_msg = f"Timeout slave_id={slave_id} register={address}"
            logger.warning(error_msg)
            self.modbus_error.emit(error_msg)
            return None

        registers = result.registers

        if data_type == "float32" and len(registers) == 2:
            return self._decode_float32(registers, data_format)
        elif data_type == "uint16":
            return registers[0]
        else:
            return self._convert_signed(registers[0])

    @staticmethod
    def _convert_signed(value: int, bits: int = 16) -> int:
        if value >= (1 << (bits - 1)):
            value -= 1 << bits
        return value

    @staticmethod
    def _decode_float32(registers: list[int], data_format: str) -> float:
        if data_format == "CDAB":
            raw_bytes = struct.pack(">HH", registers[1], registers[0])
        elif data_format == "BADC":
            raw_bytes = struct.pack("<HH", registers[0], registers[1])
        elif data_format == "DCBA":
            raw_bytes = struct.pack("<HH", registers[1], registers[0])
        else:  # ABCD — Big-endian (default)
            raw_bytes = struct.pack(">HH", registers[0], registers[1])

        return struct.unpack(">f", raw_bytes)[0]
