"""M3 — MonitorController + MonitorModel.

MonitorModel: QAbstractListModel cung cấp dữ liệu realtime cho QML GridView.
MonitorController: Quản lý QThread cho ModbusWorker + DatabaseWorker,
                     nhận data_ready → update model + enqueue DB.
"""

import logging
from datetime import datetime
from typing import Any

from PySide6.QtCore import (
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    QObject,
    QThread,
    Qt,
    Property,
    Signal,
    Slot,
)
from sqlmodel import select

from core.database import get_session
from core.exporters.base import Exporter
from models.app_config import AppConfig
from models.digital_io import DigitalIO
from models.sensor import Sensor
from workers.database_worker import DatabaseWorker
from workers.modbus_worker import ModbusWorker

logger = logging.getLogger("datalogger.monitor")

# ── MonitorModel ─────────────────────────────────────────────────────────

# Predefined palette for DI legend dots (max 8 distinct labels)
_DI_PALETTE = [
    "#E53935",  # Red
    "#1E88E5",  # Blue
    "#FDD835",  # Yellow
    "#43A047",  # Green
    "#FB8C00",  # Orange
    "#8E24AA",  # Purple
    "#00ACC1",  # Cyan
    "#F06292",  # Pink
]

_DASH_ROLES = {
    Qt.UserRole + 1: b"sensorId",
    Qt.UserRole + 2: b"name",
    Qt.UserRole + 3: b"unit",
    Qt.UserRole + 4: b"value",
    Qt.UserRole + 5: b"rawValue",
    Qt.UserRole + 6: b"status",
    Qt.UserRole + 7: b"lastUpdate",
    Qt.UserRole + 8: b"isAlarm",
    Qt.UserRole + 9: b"alarmType",
    Qt.UserRole + 10: b"diStates",
}

_DASH_FIELD = {
    b"sensorId": "sensor_id",
    b"name": "name",
    b"unit": "unit",
    b"value": "value",
    b"rawValue": "raw_value",
    b"status": "status",
    b"lastUpdate": "last_update",
    b"isAlarm": "is_alarm",
    b"alarmType": "alarm_type",
    b"diStates": "di_states",
}


class MonitorModel(QAbstractListModel):
    """Model cho MonitorView — mỗi row là 1 sensor card."""

    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._items: list[dict] = []
        self._id_to_row: dict[int, int] = {}

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid() or index.row() >= len(self._items):
            return None
        role_name = _DASH_ROLES.get(role)
        if role_name is None:
            return None
        field = _DASH_FIELD[role_name]
        return self._items[index.row()].get(field)

    def roleNames(self):
        return {k: QByteArray(v) for k, v in _DASH_ROLES.items()}

    def load_sensors(self, sensors: list[Sensor]) -> None:
        self.beginResetModel()
        self._items = []
        self._id_to_row = {}
        for i, s in enumerate(sensors):
            self._items.append({
                "sensor_id": s.id,
                "name": s.name,
                "unit": s.unit,
                "value": "---",
                "raw_value": "---",
                "status": "WAIT",
                "last_update": "",
                "is_alarm": False,
                "alarm_type": "",
                "di_states": [],
            })
            self._id_to_row[s.id] = i
        self.endResetModel()
        self.countChanged.emit()

    def update_value(self, sensor_id: int, value: float, raw_value,
                     recorded_at: str, is_alarm: bool = False,
                     alarm_type: str = "",
                     di_states: list | None = None) -> None:
        row = self._id_to_row.get(sensor_id)
        if row is None:
            return
        item = self._items[row]
        item["value"] = str(round(value, 4))
        item["raw_value"] = str(raw_value)
        item["status"] = "ALARM" if is_alarm else "OK"
        item["is_alarm"] = is_alarm
        item["alarm_type"] = alarm_type
        if di_states is not None:
            item["di_states"] = di_states
        try:
            dt = datetime.fromisoformat(recorded_at)
            item["last_update"] = dt.strftime("%H:%M:%S")
        except Exception:
            item["last_update"] = recorded_at
        idx = self.index(row, 0)
        self.dataChanged.emit(idx, idx, [])

    def set_sensor_status(self, sensor_id: int, status: str) -> None:
        row = self._id_to_row.get(sensor_id)
        if row is None:
            return
        self._items[row]["status"] = status
        idx = self.index(row, 0)
        self.dataChanged.emit(idx, idx, [])

    def set_all_status(self, status: str) -> None:
        for i, item in enumerate(self._items):
            item["status"] = status
        if self._items:
            self.dataChanged.emit(
                self.index(0, 0),
                self.index(len(self._items) - 1, 0),
                [],
            )


# ── MonitorController ───────────────────────────────────────────────────

class MonitorController(QObject):
    """Điều khiển polling Modbus + ghi DB + cập nhật Monitor realtime."""

    # statusMode values (used in QML instead of string matching)
    STATUS_IDLE = 0   # Not polling / stopped / ready
    STATUS_OK   = 1   # Polling and connected
    STATUS_ERR  = 2   # Polling but disconnected / error

    pollingChanged = Signal()
    stoppingChanged = Signal()
    statusChanged = Signal()
    cpuTempChanged = Signal()

    @Property(float, notify=cpuTempChanged)
    def cpuTemp(self):
        return self._cpu_temp
    errorCountChanged = Signal()
    activeSensorsChanged = Signal()
    diLegendChanged = Signal()
    messageSent = Signal(str, str)
    recordsCommitted = Signal(int)
    watchdogChanged = Signal()
    watchdogAlert = Signal(str)

    def __init__(self, monitor_model: MonitorModel, tester_controller=None, parent=None):
        super().__init__(parent)
        self._model = monitor_model
        self._tester = tester_controller
        self._is_polling = False
        self._is_stopping = False
        self._status_tag = "ready"
        self._status_mode = self.STATUS_IDLE
        self._error_count = 0
        self._di_legend: list[dict] = []       # [{"label": ..., "color": ...}, ...]
        self._di_label_to_color: dict[str, str] = {}  # label → hex color

        self._modbus_worker: ModbusWorker | None = None
        self._db_worker: DatabaseWorker | None = None
        self._modbus_thread: QThread | None = None
        self._db_thread: QThread | None = None

        self._exporter: Exporter | None = None
        self._init_exporter()
        
        self._cpu_temp = 0.0
        from PySide6.QtCore import QTimer
        self._sys_timer = QTimer(self)
        self._sys_timer.setInterval(10000)
        self._sys_timer.timeout.connect(self._read_cpu_temp)
        self._sys_timer.start()

        # Watchdog logic
        self._watchdog_timer = QTimer(self)
        self._watchdog_timer.setInterval(5000)
        self._watchdog_timer.timeout.connect(self._check_watchdog)
        self._heartbeats = {
            "ModbusWorker": 0,
            "DatabaseWorker": 0,
            "FtpWorker": 0
        }
        self._watchdog_status = "N/A"
        # Track when we last received a heartbeat
        self._last_heartbeat_time = {
            "ModbusWorker": 0,
            "DatabaseWorker": 0,
            "FtpWorker": 0
        }

    # ── Properties ─────────────────────────────────────────────────────────

    @Property(bool, notify=pollingChanged)
    def isPolling(self):
        return self._is_polling

    @Property(bool, notify=stoppingChanged)
    def isStopping(self):
        return self._is_stopping

    @Property(str, notify=statusChanged)
    def statusText(self):
        return self._localized_status_text()

    @Property(int, notify=errorCountChanged)
    def errorCount(self):
        return self._error_count

    @Property(int, notify=statusChanged)
    def statusMode(self):
        """0=idle, 1=ok/collecting, 2=error/disconnected — dùng trong QML thay vì so sánh string."""
        return self._status_mode

    @Property(bool, notify=activeSensorsChanged)
    def hasActiveSensors(self):
        return self._model.rowCount() > 0

    @Property("QVariant", notify=diLegendChanged)
    def diLegend(self):
        """List of {label, color} dicts for QML legend display."""
        return self._di_legend

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def refresh_status_display(self):
        """Gọi khi đổi ngôn ngữ — QML đọc lại statusText qua tr()."""
        self.statusChanged.emit()

    @Slot()
    def refresh_sensors(self):
        """Reload active sensors into the monitor model (only when not polling)."""
        if self._is_polling:
            return
        session = get_session()
        try:
            sensors = list(
                session.exec(select(Sensor).where(Sensor.active)).all()
            )
            self._model.load_sensors(sensors)
            self.activeSensorsChanged.emit()
        except Exception as e:
            logger.error("refresh_sensors error: %s", e)
        finally:
            session.close()

    @Property(str, notify=watchdogChanged)
    def watchdogStatus(self):
        return self._watchdog_status

    @Slot(str)
    def register_heartbeat(self, worker_name: str):
        import time
        if worker_name in self._last_heartbeat_time:
            self._last_heartbeat_time[worker_name] = time.monotonic()
            self._heartbeats[worker_name] = 0

    def _init_exporter(self):
        """Initialize Cloud Exporter if enabled in config.toml."""
        import tomllib
        from core._paths import CONFIG_DIR
        try:
            config_file = CONFIG_DIR / "config.toml"
            if not config_file.exists():
                logger.debug(f"Config file not found: {config_file}. Exporter will not start.")
                return
            
            with open(config_file, "rb") as f:
                cfg = tomllib.load(f)
                cloud_cfg = cfg.get("cloud", {})
                if cloud_cfg.get("enable_mqtt", False):
                    from core.exporters.mqtt import MQTTExporter
                    self._exporter = MQTTExporter(
                        host=cloud_cfg.get("mqtt_host", "localhost"),
                        port=cloud_cfg.get("mqtt_port", 1883),
                        topic=cloud_cfg.get("mqtt_topic", "datalogger/telemetry")
                    )
        except Exception as e:
            logger.error(f"Failed to init exporter: {e}")

    def _read_cpu_temp(self):
        try:
            with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
                temp_str = f.read().strip()
                temp = float(temp_str) / 1000.0
                if self._cpu_temp != temp:
                    self._cpu_temp = temp
                    self.cpuTempChanged.emit()
        except Exception:
            pass

    def _check_watchdog(self):
        import time
        from PySide6.QtCore import QTimer
        now = time.monotonic()
        misses = []
        for worker, last_time in self._last_heartbeat_time.items():
            if last_time > 0 and (now - last_time) > 6.0:  # Allow 6s for 5s heartbeat
                self._heartbeats[worker] += 1
                if self._heartbeats[worker] > 3:  # >3 continuous misses
                    misses.append(worker)
            
        if misses:
            self._watchdog_status = f"ERR: {','.join(misses)}"
            for m in misses:
                self.watchdogAlert.emit(f"Worker dead: {m}")
                logger.error(f"Watchdog alert: {m} dead. Auto-restarting if possible.")
                # We auto-restart Modbus or DB worker
                if m in ("DatabaseWorker", "ModbusWorker") and self._is_polling:
                    self.stop_polling_sync()
                    QTimer.singleShot(2000, self.start_polling)
        else:
            self._watchdog_status = "OK"
            
        self.watchdogChanged.emit()

    @Slot()
    def start_polling(self):
        if self._is_polling:
            return

        if self._tester and self._tester._is_connected:
            self._tester.disconnect_serial()

        session = get_session()
        try:
            cfg = session.exec(select(AppConfig)).first()
            if cfg is None:
                self.messageSent.emit(
                    "Error",
                    "No system configuration yet. Open Settings to set up.",
                )
                return

            sensors = list(
                session.exec(select(Sensor).where(Sensor.active)).all()
            )
            if not sensors:
                self.messageSent.emit(
                    "Error",
                    "No active sensors. Open Settings to add sensors.",
                )
                return

            self._model.load_sensors(sensors)

            sensor_dicts = [
                {
                    "id": s.id,
                    "slave_id": s.slave_id,
                    "register_address": s.register_address,
                    "register_type": s.register_type,
                    "data_type": s.data_type,
                    "data_format": s.data_format,
                    "coefficient": s.coefficient or "{}",
                    "poll_interval": s.poll_interval,
                    "min_threshold": s.min_threshold,
                    "max_threshold": s.max_threshold,
                }
                for s in sensors
            ]

            # Load Digital I/O configs grouped by sensor_id (only from active sensors)
            active_sensor_ids = [s.id for s in sensors]
            all_ios = list(session.exec(
                select(DigitalIO)
                .where(DigitalIO.active)
                .where(DigitalIO.sensor_id.in_(active_sensor_ids))
            ).all())
            digital_io_map: dict[int, list[dict]] = {}
            for io in all_ios:
                dio_dict = {
                    "id": io.id,
                    "io_type": io.io_type,
                    "label": io.label,
                    "di_type": io.di_type,
                    "slave_id": io.slave_id,
                    "address": io.address,
                    "trigger_on_max": io.trigger_on_max,
                    "trigger_on_min": io.trigger_on_min,
                    "active": io.active,
                }
                digital_io_map.setdefault(io.sensor_id, []).append(dio_dict)

            # Build DI legend — assign a unique color to each distinct DI label
            self._build_di_legend(all_ios)

            # DatabaseWorker thread
            self._db_worker = DatabaseWorker()
            self._db_thread = QThread()
            self._db_worker.moveToThread(self._db_thread)
            self._db_thread.started.connect(self._db_worker.run)
            self._db_worker.worker_stopped.connect(self._db_thread.quit)
            self._db_worker.db_error.connect(self._on_db_error)
            self._db_worker.records_saved.connect(self._on_records_saved)
            self._db_worker.heartbeat.connect(self.register_heartbeat)

            # ModbusWorker thread
            self._modbus_worker = ModbusWorker(
                port=cfg.serial_port,
                baudrate=cfg.serial_baudrate,
                bytesize=cfg.serial_bytesize,
                parity=cfg.serial_parity,
                stopbits=cfg.serial_stopbits,
                timeout=1,
                poll_interval=cfg.poll_interval,
            )
            self._modbus_worker.set_sensors(sensor_dicts)
            self._modbus_worker.set_digital_ios(digital_io_map)

            self._modbus_thread = QThread()
            self._modbus_worker.moveToThread(self._modbus_thread)
            self._modbus_thread.started.connect(self._modbus_worker.run)
            self._modbus_worker.worker_stopped.connect(self._on_modbus_stopped)
            self._modbus_worker.data_ready.connect(self._on_data_ready)
            self._modbus_worker.modbus_error.connect(self._on_modbus_error)
            self._modbus_worker.connection_changed.connect(self._on_connection_changed)
            self._modbus_worker.alarm_changed.connect(self._on_alarm_changed)
            self._modbus_worker.heartbeat.connect(self.register_heartbeat)

            if getattr(self, "_exporter", None):
                self._exporter.connect()

            self._db_thread.start()
            self._modbus_thread.start()

            self._watchdog_timer.start()
            import time
            for w in self._last_heartbeat_time:
                self._last_heartbeat_time[w] = time.monotonic()

            self._is_polling = True
            self._error_count = 0
            self._apply_status("monitoring", self.STATUS_OK)
            self.pollingChanged.emit()
            self.errorCountChanged.emit()
            logger.info("Polling started: %d sensors, interval=%ds", len(sensors), cfg.poll_interval)

        except Exception as e:
            logger.error("start_polling error: %s", e, exc_info=True)
            self.messageSent.emit(
                "Error",
                "Could not start polling: {0}".format(e),
            )
        finally:
            session.close()

    @Slot()
    def stop_polling(self):
        """Request an async (non-blocking) stop of both worker threads."""
        if not self._is_polling or self._is_stopping:
            return
            
        if getattr(self, "_exporter", None):
            self._exporter.disconnect()

        self._watchdog_timer.stop()
        self._is_stopping = True
        self._apply_status("stopping", self.STATUS_IDLE)
        self.stoppingChanged.emit()
        logger.info("Stopping polling (async)…")

        if self._modbus_worker:
            self._modbus_worker.stop()
        if self._db_worker:
            self._db_worker.stop()

        if self._modbus_thread and self._modbus_thread.isRunning():
            self._modbus_thread.quit()
        if self._db_thread and self._db_thread.isRunning():
            self._db_thread.quit()

        self._check_threads_finished()

    def _check_threads_finished(self) -> None:
        modbus_done = self._modbus_thread is None or not self._modbus_thread.isRunning()
        db_done = self._db_thread is None or not self._db_thread.isRunning()

        if modbus_done and db_done:
            self._finalize_stop()
        else:
            from PySide6.QtCore import QTimer
            QTimer.singleShot(50, self._check_threads_finished)

    def _finalize_stop(self) -> None:
        self._modbus_worker = None
        self._db_worker = None
        self._modbus_thread = None
        self._db_thread = None

        self._is_polling = False
        self._is_stopping = False
        self._apply_status("stopped", self.STATUS_IDLE)
        self.pollingChanged.emit()
        self.stoppingChanged.emit()
        self._model.set_all_status("---")
        logger.info("Polling stopped.")

    @Slot()
    def stop_polling_sync(self):
        """Synchronous stop — only for app shutdown (aboutToQuit)."""
        if not self._is_polling:
            return
            
        if getattr(self, "_exporter", None):
            self._exporter.disconnect()
            
        self._watchdog_timer.stop()
        if self._modbus_worker:
            self._modbus_worker.stop()
        if self._db_worker:
            self._db_worker.stop()
        if self._modbus_thread and self._modbus_thread.isRunning():
            self._modbus_thread.quit()
            self._modbus_thread.wait(5000)
        if self._db_thread and self._db_thread.isRunning():
            self._db_thread.quit()
            self._db_thread.wait(5000)
        self._is_polling = False
        self._is_stopping = False
        logger.info("Polling stopped (sync shutdown).")

    # ── Internal signal handlers ───────────────────────────────────────────

    def _on_data_ready(self, payload: dict) -> None:
        if not self._is_polling or self._is_stopping:
            return

        # Build colored DI states for QML (only active DIs with state=True)
        raw_di = payload.get("di_states", [])
        colored_di = []
        for di in raw_di:
            if di.get("state"):
                label = di.get("label", "")
                color = self._di_label_to_color.get(label, "#888888")
                colored_di.append({"label": label, "color": color})

        self._model.update_value(
            sensor_id=payload["sensor_id"],
            value=payload["value"],
            raw_value=payload["raw_value"],
            recorded_at=payload["recorded_at"],
            is_alarm=payload.get("is_alarm", False),
            alarm_type=payload.get("alarm_type", ""),
            di_states=colored_di,
        )
        if self._db_worker:
            self._db_worker.enqueue(payload)
            
        # Cloud Exporter Skeleton
        if self._exporter:
            # Here we could enhance the code to also support HTTP REST endpoints.
            # Example: self._exporter (can be polymorphic Exporter abc class handling JSON payload)
            self._exporter.send(payload)

    def _on_alarm_changed(self, info: dict) -> None:
        """Handle alarm state transitions from ModbusWorker."""
        sid = info.get("sensor_id")
        is_alarm = info.get("is_alarm", False)
        alarm_type = info.get("alarm_type", "")
        if is_alarm:
            logger.warning(
                "⚠️ ALARM sensor=%d type=%s", sid, alarm_type,
            )
        else:
            logger.info("✅ Alarm cleared sensor=%d", sid)

    def _on_modbus_error(self, msg: str) -> None:
        if self._is_stopping:
            return
        self._error_count += 1
        self.errorCountChanged.emit()
        logger.warning("Modbus error #%d: %s", self._error_count, msg)

    def _on_connection_changed(self, connected: bool) -> None:
        if self._is_stopping:
            return
        if connected:
            self._apply_status("monitoring", self.STATUS_OK)
        else:
            self._apply_status("connection_lost", self.STATUS_ERR)
            self._model.set_all_status("ERR")

    def _on_modbus_stopped(self) -> None:
        if self._modbus_thread and self._modbus_thread.isRunning():
            self._modbus_thread.quit()

        if self._is_stopping:
            return

        if self._is_polling:
            logger.warning("Modbus worker exited unexpectedly — stopping all workers.")
            self._is_stopping = True
            self._apply_status("stopped_worker", self.STATUS_ERR)
            self.stoppingChanged.emit()

            if self._db_worker:
                self._db_worker.stop()
            if self._db_thread and self._db_thread.isRunning():
                self._db_thread.quit()

            self._check_threads_finished()

    def _on_db_error(self, msg: str) -> None:
        logger.error("DB error: %s", msg)

    def _on_records_saved(self, count: int) -> None:
        logger.debug("DB saved %d records", count)
        self.recordsCommitted.emit(count)

    def _localized_status_text(self) -> str:
        tag = self._status_tag
        if tag == "monitoring":
            return "Monitoring…"
        if tag == "stopping":
            return "Stopping…"
        if tag == "connection_lost":
            return "Connection lost — retrying…"
        if tag == "stopped":
            return "Stopped"
        if tag == "stopped_worker":
            return "Stopped (worker exited)"
        return "Ready"

    def _apply_status(self, tag: str, mode: int | None = None) -> None:
        self._status_tag = tag
        if mode is not None:
            self._status_mode = mode
        self.statusChanged.emit()

    def _build_di_legend(self, all_ios: list) -> None:
        """Assign a unique color to each distinct DI label across all sensors."""
        seen_labels: list[str] = []
        for io in all_ios:
            if io.io_type == "DI" and io.label not in seen_labels:
                seen_labels.append(io.label)

        self._di_label_to_color = {}
        self._di_legend = []
        for i, label in enumerate(seen_labels):
            color = _DI_PALETTE[i % len(_DI_PALETTE)]
            self._di_label_to_color[label] = color
            self._di_legend.append({"label": label, "color": color})

        self.diLegendChanged.emit()
        logger.info("DI legend built: %s", self._di_legend)
