"""M4 — HistoryController + HistoryModel + SearchWorker.

HistoryModel: QAbstractListModel cho QML ListView hiển thị sensor_data.
HistoryController: Truy vấn lịch sử (QThread); khi tab History mở — đồng bộ theo
recordsCommitted (ghi DB batch); incremental theo watermark id.
"""

import csv
import logging
from datetime import datetime, timedelta
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
from models.sensor import Sensor
from models.sensor_data import SensorData

logger = logging.getLogger("datalogger.history")

# ── HistoryModel ───────────────────────────────────────────────────────────

_HIST_ROLES = {
    Qt.UserRole + 1: b"recordedAt",
    Qt.UserRole + 2: b"sensorName",
    Qt.UserRole + 3: b"unit",
    Qt.UserRole + 4: b"value",
    Qt.UserRole + 5: b"rawValue",
}

_HIST_FIELD = {
    b"recordedAt": "recorded_at",
    b"sensorName": "sensor_name",
    b"unit": "unit",
    b"value": "value",
    b"rawValue": "raw_value",
}

MAX_RECORDS = 5000
INCREMENTAL_FETCH_LIMIT = 500


def _row_dict(r: SensorData, sensors: dict[int, Sensor]) -> dict:
    s = sensors.get(r.sensor_id)
    return {
        "id": r.id,
        "recorded_at": r.recorded_at.strftime("%d/%m/%Y %H:%M:%S") if r.recorded_at else "",
        "sensor_name": s.name if s else f"ID#{r.sensor_id}",
        "unit": s.unit if s else "",
        "value": str(round(r.value, 4)) if r.value is not None else "---",
        "raw_value": str(r.raw_value) if r.raw_value is not None else "---",
    }


class HistoryModel(QAbstractListModel):
    """Model cho HistoryView — mỗi row là 1 bản ghi sensor_data."""

    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._items: list[dict] = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid() or index.row() >= len(self._items):
            return None
        role_name = _HIST_ROLES.get(role)
        if role_name is None:
            return None
        field = _HIST_FIELD[role_name]
        return self._items[index.row()].get(field)

    def roleNames(self):
        return {k: QByteArray(v) for k, v in _HIST_ROLES.items()}

    def set_data(self, items: list[dict]) -> None:
        self.beginResetModel()
        self._items = items
        self.endResetModel()
        self.countChanged.emit()

    def get_all(self) -> list[dict]:
        return self._items

    def prepend_and_trim(self, new_items_newest_first: list[dict], max_rows: int) -> None:
        """Thêm các dòng mới (mới nhất trước) vào đầu list; cắt phần cũ ở cuối."""
        if not new_items_newest_first:
            return
        n_new = len(new_items_newest_first)
        old_len = len(self._items)
        total = old_len + n_new
        to_remove = max(0, total - max_rows)

        self.beginInsertRows(QModelIndex(), 0, n_new - 1)
        self._items = new_items_newest_first + self._items
        self.endInsertRows()

        if to_remove > 0:
            start_rm = len(self._items) - to_remove
            self.beginRemoveRows(QModelIndex(), start_rm, len(self._items) - 1)
            self._items = self._items[:start_rm]
            self.endRemoveRows()
        self.countChanged.emit()


# ── SearchWorker ───────────────────────────────────────────────────────────


class SearchWorker(QThread):
    """Truy vấn sensor_data trên thread riêng (read-only)."""

    finished = Signal(list)
    error = Signal(str)

    def __init__(
        self,
        from_dt: datetime,
        to_dt: datetime,
        sensor_id: int = 0,
        parent=None,
    ):
        super().__init__(parent)
        self._from_dt = from_dt
        self._to_dt = to_dt
        self._sensor_id = sensor_id
        self._cancel_requested = False

    def request_cancel(self) -> None:
        self._cancel_requested = True

    def run(self):
        session = get_session()
        try:
            sensors = {s.id: s for s in session.exec(select(Sensor)).all()}

            stmt = select(SensorData).where(
                SensorData.recorded_at >= self._from_dt,
                SensorData.recorded_at <= self._to_dt,
            )
            if self._sensor_id > 0:
                stmt = stmt.where(SensorData.sensor_id == self._sensor_id)

            stmt = stmt.order_by(SensorData.recorded_at.desc()).limit(MAX_RECORDS)
            rows = session.exec(stmt).all()

            if self._cancel_requested:
                return

            items = []
            for r in rows:
                items.append(_row_dict(r, sensors))

            if self._cancel_requested:
                return

            self.finished.emit(items)
        except Exception as e:
            logger.error("SearchWorker error: %s", e, exc_info=True)
            if not self._cancel_requested:
                self.error.emit(str(e))
        finally:
            session.close()


# ── IncrementalFetchWorker ───────────────────────────────────────────────────


class IncrementalFetchWorker(QThread):
    """Lấy các bản ghi mới hơn after_id trong cùng filter ngày/sensor."""

    finished = Signal(list)
    error = Signal(str)

    def __init__(
        self,
        from_dt: datetime,
        to_dt: datetime,
        sensor_id: int,
        after_id: int,
        limit: int = INCREMENTAL_FETCH_LIMIT,
        parent=None,
    ):
        super().__init__(parent)
        self._from_dt = from_dt
        self._to_dt = to_dt
        self._sensor_id = sensor_id
        self._after_id = after_id
        self._limit = limit
        self._cancel_requested = False

    def request_cancel(self) -> None:
        self._cancel_requested = True

    def run(self):
        session = get_session()
        try:
            sensors = {s.id: s for s in session.exec(select(Sensor)).all()}

            stmt = (
                select(SensorData)
                .where(SensorData.id > self._after_id)
                .where(SensorData.recorded_at >= self._from_dt)
                .where(SensorData.recorded_at <= self._to_dt)
            )
            if self._sensor_id > 0:
                stmt = stmt.where(SensorData.sensor_id == self._sensor_id)

            stmt = stmt.order_by(SensorData.id.asc()).limit(self._limit)
            rows = session.exec(stmt).all()

            if self._cancel_requested:
                return

            items = [_row_dict(r, sensors) for r in rows]

            if self._cancel_requested:
                return

            self.finished.emit(items)
        except Exception as e:
            logger.error("IncrementalFetchWorker error: %s", e, exc_info=True)
            if not self._cancel_requested:
                self.error.emit(str(e))
        finally:
            session.close()


# ── HistoryController ──────────────────────────────────────────────────────


class HistoryController(QObject):
    """Điều khiển truy vấn lịch sử; live khi tab History mở và đang monitoring."""

    loadingChanged = Signal()
    recordCountChanged = Signal()
    messageSent = Signal(str, str)
    sensorsChanged = Signal()
    chartDataChanged = Signal()

    def __init__(self, history_model: HistoryModel, parent=None):
        super().__init__(parent)
        self._model = history_model
        self._is_loading = False
        self._record_count = 0
        self._chart_data: list[dict] = []
        self._worker: SearchWorker | None = None
        self._incr_worker: IncrementalFetchWorker | None = None
        self._sensor_names: list[str] = ["— All —"]
        self._sensor_ids: list[int] = [0]

        self._monitor: QObject | None = None
        self._history_active = False
        self._records_hooked = False

        self._query_from_dt: datetime | None = None
        self._query_to_dt: datetime | None = None
        self._query_sensor_id: int = 0
        self._max_row_id: int = 0
        self._incr_busy = False

    @Property(bool, notify=loadingChanged)
    def isLoading(self):
        return self._is_loading

    @Property(int, notify=recordCountChanged)
    def recordCount(self):
        return self._record_count

    @Property("QVariantList", notify=chartDataChanged)
    def chartData(self):
        return self._chart_data

    @Property("QStringList", notify=sensorsChanged)
    def sensorNames(self):
        return self._sensor_names

    @Property("QVariantList", notify=sensorsChanged)
    def sensorIds(self):
        return self._sensor_ids

    def attach_monitor(self, monitor: QObject) -> None:
        """Gọi một lần từ main — MonitorController phát recordsCommitted."""
        self._monitor = monitor

    @Slot(bool)
    def setHistoryTabActive(self, active: bool) -> None:
        """QML: tab History đang hiển thị — bật/tắt đọc live và hủy worker khi rời tab."""
        self._history_active = active
        if active:
            self._connect_records_signal()
        else:
            self._disconnect_records_signal()
            self._abort_workers()

    def _connect_records_signal(self) -> None:
        if self._monitor is None or self._records_hooked:
            return
        try:
            self._monitor.recordsCommitted.connect(self._on_records_committed)
            self._records_hooked = True
        except Exception as e:
            logger.warning("attach recordsCommitted failed: %s", e)

    def _disconnect_records_signal(self) -> None:
        if self._monitor is None or not self._records_hooked:
            return
        try:
            self._monitor.recordsCommitted.disconnect(self._on_records_committed)
        except (TypeError, RuntimeError):
            pass
        self._records_hooked = False

    def _abort_workers(self) -> None:
        if self._worker:
            self._worker.request_cancel()
            try:
                self._worker.finished.disconnect(self._handle_search_finished)
                self._worker.error.disconnect(self._handle_search_error)
            except (TypeError, RuntimeError):
                pass
            self._worker = None
        if self._is_loading:
            self._is_loading = False
            self.loadingChanged.emit()

        if self._incr_worker:
            self._incr_worker.request_cancel()
            try:
                self._incr_worker.finished.disconnect(self._on_incremental_done)
                self._incr_worker.error.disconnect(self._on_incremental_error)
            except (TypeError, RuntimeError):
                pass
            self._incr_worker = None
        self._incr_busy = False

    def _on_records_committed(self, count: int) -> None:
        del count  # batch size — dùng watermark id
        if not self._history_active:
            return
        if self._monitor is None:
            return
        try:
            polling = bool(getattr(self._monitor, "isPolling", False))
        except Exception:
            polling = False
        if not polling:
            return
        if self._query_from_dt is None or self._query_to_dt is None:
            return
        if self._max_row_id <= 0:
            return
        if self._incr_busy:
            return
        self._start_incremental_fetch()

    def _start_incremental_fetch(self) -> None:
        if self._incr_busy or self._query_from_dt is None or self._query_to_dt is None:
            return
        self._incr_busy = True
        w = IncrementalFetchWorker(
            self._query_from_dt,
            self._query_to_dt,
            self._query_sensor_id,
            self._max_row_id,
            INCREMENTAL_FETCH_LIMIT,
            self,
        )
        self._incr_worker = w
        w.finished.connect(self._on_incremental_done)
        w.error.connect(self._on_incremental_error)
        w.start()

    def _on_incremental_done(self, items: list[dict]) -> None:
        w = self.sender()
        if w is not self._incr_worker:
            return
        self._incr_busy = False
        self._incr_worker = None
        if not self._history_active:
            return
        if not items:
            return
        ids = [i.get("id") for i in items if i.get("id") is not None]
        if ids:
            self._max_row_id = max(self._max_row_id, max(ids))
        newest_first = list(reversed(items))
        self._model.prepend_and_trim(newest_first, MAX_RECORDS)
        self._record_count = len(self._model.get_all())
        self._chart_data = self._build_chart_data(self._model.get_all())
        self.recordCountChanged.emit()
        self.chartDataChanged.emit()
        logger.debug("History incremental: +%d rows, max_id=%s", len(items), self._max_row_id)

    def _on_incremental_error(self, msg: str) -> None:
        w = self.sender()
        if w is not self._incr_worker:
            return
        self._incr_busy = False
        self._incr_worker = None
        if self._history_active:
            self.messageSent.emit("Error", "Incremental query failed: {0}".format(msg))

    @Slot()
    def load_sensors(self):
        session = get_session()
        try:
            sensors = list(session.exec(select(Sensor).order_by(Sensor.name)).all())
            self._sensor_names = ["— All —"] + [s.name for s in sensors]
            self._sensor_ids = [0] + [s.id for s in sensors]
            self.sensorsChanged.emit()
        except Exception as e:
            logger.error("load_sensors error: %s", e)
        finally:
            session.close()

    @Slot(str, str, int)
    def search(self, from_date: str, to_date: str, sensor_id: int = 0):
        if self._is_loading:
            return

        try:
            from_dt = datetime.strptime(from_date, "%d/%m/%Y")
            to_dt = datetime.strptime(to_date, "%d/%m/%Y") + timedelta(
                hours=23, minutes=59, seconds=59
            )
        except ValueError:
            self.messageSent.emit(
                "Error",
                "Invalid date format. Use dd/MM/yyyy.",
            )
            return

        if from_dt > to_dt:
            self.messageSent.emit(
                "Error",
                "Start date must be before end date.",
            )
            return

        if self._worker:
            self._worker.request_cancel()
            try:
                self._worker.finished.disconnect(self._handle_search_finished)
                self._worker.error.disconnect(self._handle_search_error)
            except (TypeError, RuntimeError):
                pass
            self._worker = None

        if self._incr_worker:
            self._incr_worker.request_cancel()
            try:
                self._incr_worker.finished.disconnect(self._on_incremental_done)
                self._incr_worker.error.disconnect(self._on_incremental_error)
            except (TypeError, RuntimeError):
                pass
            self._incr_worker = None
        self._incr_busy = False

        self._is_loading = True
        self.loadingChanged.emit()

        self._query_from_dt = from_dt
        self._query_to_dt = to_dt
        self._query_sensor_id = sensor_id

        self._worker = SearchWorker(from_dt, to_dt, sensor_id)
        self._worker.finished.connect(self._handle_search_finished)
        self._worker.error.connect(self._handle_search_error)
        self._worker.start()

    @Slot(str)
    def export_csv(self, path: str):
        """Xuất dữ liệu hiện tại ra file CSV (UTF-8 BOM)."""
        items = self._model.get_all()
        if not items:
            self.messageSent.emit(
                "Notice",
                "No data to export.",
            )
            return

        try:
            with open(path, "w", newline="", encoding="utf-8-sig") as f:
                writer = csv.writer(f)
                writer.writerow(
                    [
                        "Time",
                        "Sensor",
                        "Unit",
                        "Value",
                        "Raw value",
                    ]
                )
                for item in items:
                    writer.writerow(
                        [
                            item["recorded_at"],
                            item["sensor_name"],
                            item["unit"],
                            item["value"],
                            item["raw_value"],
                        ]
                    )

            logger.info("CSV exported: %s (%d rows)", path, len(items))
        except Exception as e:
            logger.error("export_csv error: %s", e, exc_info=True)
            self.messageSent.emit(
                "Error",
                "CSV export failed: {0}".format(e),
            )

    def _handle_search_finished(self, items: list[dict]) -> None:
        w = self.sender()
        if w is not self._worker:
            return
        self._worker = None
        self._model.set_data(items)
        self._record_count = len(items)
        ids = [i.get("id") for i in items if i.get("id") is not None]
        self._max_row_id = max(ids) if ids else 0
        self._chart_data = self._build_chart_data(items)
        self._is_loading = False
        self.loadingChanged.emit()
        self.recordCountChanged.emit()
        self.chartDataChanged.emit()

        logger.info("Search done: %d records, max_id=%s", len(items), self._max_row_id)

    def _handle_search_error(self, msg: str) -> None:
        w = self.sender()
        if w is not self._worker:
            return
        self._worker = None
        self._is_loading = False
        self.loadingChanged.emit()
        self.messageSent.emit(
            "Error",
            "Query failed: {0}".format(msg),
        )

    @staticmethod
    def _build_chart_data(items: list[dict]) -> list[dict]:
        groups: dict[str, list] = {}
        for item in reversed(items):
            name = item["sensor_name"]
            val_str = item.get("value", "---")
            if val_str == "---":
                continue
            try:
                dt = datetime.strptime(item["recorded_at"], "%d/%m/%Y %H:%M:%S")
                x = dt.timestamp() * 1000
                y = float(val_str)
            except (ValueError, TypeError):
                continue
            groups.setdefault(name, []).append({"x": x, "y": y})
        return [{"name": k, "points": v} for k, v in groups.items()]
