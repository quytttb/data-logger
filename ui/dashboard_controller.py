"""M3 — DashboardController + DashboardModel.

DashboardModel: QAbstractListModel cung cấp dữ liệu realtime cho QML GridView.
DashboardController: Quản lý QThread cho ModbusWorker + DatabaseWorker,
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
from models.app_config import AppConfig
from models.sensor import Sensor
from workers.database_worker import DatabaseWorker
from workers.modbus_worker import ModbusWorker

logger = logging.getLogger("datalogger.dashboard")

# ── DashboardModel ─────────────────────────────────────────────────────────

_DASH_ROLES = {
    Qt.UserRole + 1: b"sensorId",
    Qt.UserRole + 2: b"name",
    Qt.UserRole + 3: b"unit",
    Qt.UserRole + 4: b"value",
    Qt.UserRole + 5: b"rawValue",
    Qt.UserRole + 6: b"status",
    Qt.UserRole + 7: b"lastUpdate",
}

_DASH_FIELD = {
    b"sensorId": "sensor_id",
    b"name": "name",
    b"unit": "unit",
    b"value": "value",
    b"rawValue": "raw_value",
    b"status": "status",
    b"lastUpdate": "last_update",
}


class DashboardModel(QAbstractListModel):
    """Model cho DashboardView — mỗi row là 1 sensor card."""

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
            })
            self._id_to_row[s.id] = i
        self.endResetModel()
        self.countChanged.emit()

    def update_value(self, sensor_id: int, value: float, raw_value, recorded_at: str) -> None:
        row = self._id_to_row.get(sensor_id)
        if row is None:
            return
        item = self._items[row]
        item["value"] = str(round(value, 4))
        item["raw_value"] = str(raw_value)
        item["status"] = "OK"
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


# ── DashboardController ───────────────────────────────────────────────────

class DashboardController(QObject):
    """Điều khiển polling Modbus + ghi DB + cập nhật Dashboard realtime."""

    # statusMode values (used in QML instead of string matching)
    STATUS_IDLE = 0   # Not polling / stopped / ready
    STATUS_OK   = 1   # Polling and connected
    STATUS_ERR  = 2   # Polling but disconnected / error

    pollingChanged = Signal()
    stoppingChanged = Signal()
    statusChanged = Signal()
    errorCountChanged = Signal()
    messageSent = Signal(str, str)

    def __init__(self, dashboard_model: DashboardModel, tester_controller=None, parent=None):
        super().__init__(parent)
        self._model = dashboard_model
        self._tester = tester_controller
        self._is_polling = False
        self._is_stopping = False
        self._status_tag = "ready"
        self._status_mode = self.STATUS_IDLE
        self._error_count = 0

        self._modbus_worker: ModbusWorker | None = None
        self._db_worker: DatabaseWorker | None = None
        self._modbus_thread: QThread | None = None
        self._db_thread: QThread | None = None

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

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def refresh_status_display(self):
        """Gọi khi đổi ngôn ngữ — QML đọc lại statusText qua tr()."""
        self.statusChanged.emit()

    @Slot()
    def refresh_sensors(self):
        """Reload active sensors into the dashboard model (only when not polling)."""
        if self._is_polling:
            return
        session = get_session()
        try:
            sensors = list(
                session.exec(select(Sensor).where(Sensor.active)).all()
            )
            self._model.load_sensors(sensors)
        except Exception as e:
            logger.error("refresh_sensors error: %s", e)
        finally:
            session.close()

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
                    self.tr("Error"),
                    self.tr("No system configuration yet. Open Settings to set up."),
                )
                return

            sensors = list(
                session.exec(select(Sensor).where(Sensor.active)).all()
            )
            if not sensors:
                self.messageSent.emit(
                    self.tr("Error"),
                    self.tr("No active sensors. Open Settings to add sensors."),
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
                }
                for s in sensors
            ]

            # DatabaseWorker thread
            self._db_worker = DatabaseWorker()
            self._db_thread = QThread()
            self._db_worker.moveToThread(self._db_thread)
            self._db_thread.started.connect(self._db_worker.run)
            self._db_worker.worker_stopped.connect(self._db_thread.quit)
            self._db_worker.db_error.connect(self._on_db_error)
            self._db_worker.records_saved.connect(self._on_records_saved)

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

            self._modbus_thread = QThread()
            self._modbus_worker.moveToThread(self._modbus_thread)
            self._modbus_thread.started.connect(self._modbus_worker.run)
            self._modbus_worker.worker_stopped.connect(self._on_modbus_stopped)
            self._modbus_worker.data_ready.connect(self._on_data_ready)
            self._modbus_worker.modbus_error.connect(self._on_modbus_error)
            self._modbus_worker.connection_changed.connect(self._on_connection_changed)

            self._db_thread.start()
            self._modbus_thread.start()

            self._is_polling = True
            self._error_count = 0
            self._apply_status("acquiring", self.STATUS_OK)
            self.pollingChanged.emit()
            self.errorCountChanged.emit()
            logger.info("Polling started: %d sensors, interval=%ds", len(sensors), cfg.poll_interval)

        except Exception as e:
            logger.error("start_polling error: %s", e, exc_info=True)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Could not start polling: {0}").format(e),
            )
        finally:
            session.close()

    @Slot()
    def stop_polling(self):
        """Request an async (non-blocking) stop of both worker threads."""
        if not self._is_polling or self._is_stopping:
            return

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
        self._model.update_value(
            sensor_id=payload["sensor_id"],
            value=payload["value"],
            raw_value=payload["raw_value"],
            recorded_at=payload["recorded_at"],
        )
        if self._db_worker:
            self._db_worker.enqueue(payload)

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
            self._apply_status("acquiring", self.STATUS_OK)
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

    def _localized_status_text(self) -> str:
        tag = self._status_tag
        if tag == "acquiring":
            return self.tr("Acquiring…")
        if tag == "stopping":
            return self.tr("Stopping…")
        if tag == "connection_lost":
            return self.tr("Connection lost — retrying…")
        if tag == "stopped":
            return self.tr("Stopped")
        if tag == "stopped_worker":
            return self.tr("Stopped (worker exited)")
        return self.tr("Ready")

    def _apply_status(self, tag: str, mode: int | None = None) -> None:
        self._status_tag = tag
        if mode is not None:
            self._status_mode = mode
        self.statusChanged.emit()
