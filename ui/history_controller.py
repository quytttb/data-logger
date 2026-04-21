"""M4 — HistoryController + HistoryModel + SearchWorker.

HistoryModel: QAbstractListModel cho QML ListView hiển thị sensor_data.
HistoryController: Quản lý truy vấn lịch sử (QThread); export_csv giữ cho script/test (UI không còn nút CSV).
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


# ── SearchWorker ───────────────────────────────────────────────────────────

class SearchWorker(QThread):
    """Truy vấn sensor_data trên thread riêng (read-only)."""

    finished = Signal(list)
    error = Signal(str)

    def __init__(self, from_dt: datetime, to_dt: datetime,
                 sensor_id: int = 0, parent=None):
        super().__init__(parent)
        self._from_dt = from_dt
        self._to_dt = to_dt
        self._sensor_id = sensor_id

    def run(self):
        session = get_session()
        try:
            sensors = {
                s.id: s
                for s in session.exec(select(Sensor)).all()
            }

            stmt = (
                select(SensorData)
                .where(
                    SensorData.recorded_at >= self._from_dt,
                    SensorData.recorded_at <= self._to_dt,
                )
            )
            if self._sensor_id > 0:
                stmt = stmt.where(SensorData.sensor_id == self._sensor_id)

            stmt = stmt.order_by(SensorData.recorded_at.desc()).limit(MAX_RECORDS)
            rows = session.exec(stmt).all()

            items = []
            for r in rows:
                s = sensors.get(r.sensor_id)
                items.append({
                    "recorded_at": r.recorded_at.strftime("%d/%m/%Y %H:%M:%S") if r.recorded_at else "",
                    "sensor_name": s.name if s else f"ID#{r.sensor_id}",
                    "unit": s.unit if s else "",
                    "value": str(round(r.value, 4)) if r.value is not None else "---",
                    "raw_value": str(r.raw_value) if r.raw_value is not None else "---",
                })

            self.finished.emit(items)
        except Exception as e:
            logger.error("SearchWorker error: %s", e, exc_info=True)
            self.error.emit(str(e))
        finally:
            session.close()


# ── HistoryController ──────────────────────────────────────────────────────

class HistoryController(QObject):
    """Điều khiển truy vấn lịch sử (xuất CSV chỉ gọi từ API/script, không có UI)."""

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
        self._sensor_names: list[str] = ["— All —"]
        self._sensor_ids: list[int] = [0]

    @Property(bool, notify=loadingChanged)
    def isLoading(self):
        return self._is_loading

    @Property(int, notify=recordCountChanged)
    def recordCount(self):
        return self._record_count

    @Property("QVariantList", notify=chartDataChanged)
    def chartData(self):
        """Dữ liệu chart nhóm theo sensor: [{name, points: [{x, y}]}]."""
        return self._chart_data

    @Property("QStringList", notify=sensorsChanged)
    def sensorNames(self):
        return self._sensor_names

    @Property("QVariantList", notify=sensorsChanged)
    def sensorIds(self):
        return self._sensor_ids

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

        self._is_loading = True
        self.loadingChanged.emit()

        self._worker = SearchWorker(from_dt, to_dt, sensor_id)
        self._worker.finished.connect(self._on_search_done)
        self._worker.error.connect(self._on_search_error)
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
                    writer.writerow([
                        item["recorded_at"],
                        item["sensor_name"],
                        item["unit"],
                        item["value"],
                        item["raw_value"],
                    ])

            logger.info("CSV exported: %s (%d rows)", path, len(items))
        except Exception as e:
            logger.error("export_csv error: %s", e, exc_info=True)
            self.messageSent.emit(
                "Error",
                "CSV export failed: {0}".format(e),
            )

    def _on_search_done(self, items: list[dict]) -> None:
        self._model.set_data(items)
        self._record_count = len(items)
        self._chart_data = self._build_chart_data(items)
        self._is_loading = False
        self.loadingChanged.emit()
        self.recordCountChanged.emit()
        self.chartDataChanged.emit()

        logger.info("Search done: %d records", len(items))

    @staticmethod
    def _build_chart_data(items: list[dict]) -> list[dict]:
        """Nhóm dữ liệu theo sensor cho ChartView.

        Returns:
            [{"name": str, "points": [{"x": float_msec, "y": float}]}]
        """
        groups: dict[str, list] = {}
        # items đang desc (mới nhất trước); đảo lại để chart vẽ trái→phải
        for item in reversed(items):
            name = item["sensor_name"]
            val_str = item.get("value", "---")
            if val_str == "---":
                continue
            try:
                dt = datetime.strptime(item["recorded_at"], "%d/%m/%Y %H:%M:%S")
                x = dt.timestamp() * 1000  # msec since epoch cho DateTimeAxis
                y = float(val_str)
            except (ValueError, TypeError):
                continue
            groups.setdefault(name, []).append({"x": x, "y": y})
        return [{"name": k, "points": v} for k, v in groups.items()]

    def _on_search_error(self, msg: str) -> None:
        self._is_loading = False
        self.loadingChanged.emit()
        self.messageSent.emit(
            "Error",
            "Query failed: {0}".format(msg),
        )
