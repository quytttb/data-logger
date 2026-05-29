"""UI HistoryWidget — Tab Lịch sử, full-width layout."""

import csv
from datetime import datetime

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDateTimeEdit,
    QFileDialog,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from sqlmodel import select

from core.database import get_session
from models.sensor import Sensor
from models.sensor_data import SensorData


class HistoryWidget(QWidget):
    """Tab Lịch sử — full-width, row height 56px."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._current_data: list[dict] = []
        self._setup_ui()

    def _setup_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(12)

        # === Bộ lọc ===
        filter_row = QHBoxLayout()
        filter_row.setSpacing(8)

        lbl_from = QLabel("TỪ:")
        lbl_from.setStyleSheet("font-weight: bold; color: #8c90a0; font-size: 14px;")
        filter_row.addWidget(lbl_from)

        self._date_from = QDateTimeEdit()
        self._date_from.setDisplayFormat("dd/MM/yyyy HH:mm")
        self._date_from.setCalendarPopup(True)
        self._date_from.setDateTime(datetime.now().replace(hour=0, minute=0, second=0))
        self._date_from.setMinimumWidth(180)
        filter_row.addWidget(self._date_from)

        lbl_to = QLabel("ĐẾN:")
        lbl_to.setStyleSheet("font-weight: bold; color: #8c90a0; font-size: 14px;")
        filter_row.addWidget(lbl_to)

        self._date_to = QDateTimeEdit()
        self._date_to.setDisplayFormat("dd/MM/yyyy HH:mm")
        self._date_to.setCalendarPopup(True)
        self._date_to.setDateTime(datetime.now())
        self._date_to.setMinimumWidth(180)
        filter_row.addWidget(self._date_to)

        filter_row.addStretch()

        btn_query = QPushButton("🔍 TRUY VẤN")
        btn_query.setProperty("class", "PrimaryAction")
        btn_query.setMinimumWidth(140)
        btn_query.clicked.connect(self._on_query)
        filter_row.addWidget(btn_query)

        btn_export = QPushButton("💾 XUẤT USB (CSV)")
        btn_export.setStyleSheet(
            "background-color: #00622e; color: #7dffa2; font-weight: bold; font-size: 14px; padding: 10px 20px; border-radius: 6px;"
        )
        btn_export.setMinimumWidth(180)
        btn_export.clicked.connect(self._on_export_csv)
        filter_row.addWidget(btn_export)

        layout.addLayout(filter_row)

        # === Bảng ===
        self._table = QTableWidget()
        self._table.setColumnCount(5)
        self._table.setHorizontalHeaderLabels(["THỜI GIAN", "CẢM BIẾN", "GIÁ TRỊ", "ĐƠN VỊ", "RAW"])

        header = self._table.horizontalHeader()
        header.setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        header.setMinimumHeight(40)

        self._table.verticalHeader().setVisible(False)
        self._table.verticalHeader().setDefaultSectionSize(48)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)

        layout.addWidget(self._table)

        # === Dòng trạng thái ===
        self._count_label = QLabel("Chưa truy vấn dữ liệu.")
        self._count_label.setStyleSheet("color: #8c90a0; font-size: 13px;")
        layout.addWidget(self._count_label)

    def _on_query(self) -> None:
        dt_from = self._date_from.dateTime().toPython()
        dt_to = self._date_to.dateTime().toPython()

        session = get_session()
        try:
            sensors = {s.id: s for s in session.exec(select(Sensor)).all()}
            records = session.exec(
                select(SensorData)
                .where(SensorData.recorded_at >= dt_from)
                .where(SensorData.recorded_at <= dt_to)
                .order_by(SensorData.recorded_at.desc())
                .limit(5000)
            ).all()

            self._current_data.clear()
            self._table.setRowCount(len(records))

            for row, record in enumerate(records):
                sensor = sensors.get(record.sensor_id)
                sensor_name = sensor.name if sensor else f"ID:{record.sensor_id}"
                sensor_unit = sensor.unit if sensor else ""

                row_data = {
                    "time": record.recorded_at.strftime("%d/%m/%Y %H:%M:%S"),
                    "sensor": sensor_name,
                    "value": record.value,
                    "unit": sensor_unit,
                    "raw": record.raw_value,
                }
                self._current_data.append(row_data)

                self._table.setItem(row, 0, QTableWidgetItem(row_data["time"]))
                self._table.setItem(row, 1, QTableWidgetItem(sensor_name))

                str_val = f"{record.value:.4f}" if record.value is not None else "—"
                item_val = QTableWidgetItem(str_val)
                item_val.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                self._table.setItem(row, 2, item_val)

                self._table.setItem(row, 3, QTableWidgetItem(sensor_unit))
                self._table.setItem(row, 4, QTableWidgetItem(str(record.raw_value or "")))

            self._count_label.setText(f"TÌM THẤY: {len(records):,} BẢN GHI (tối đa 5000).")
        finally:
            session.close()

    def _on_export_csv(self) -> None:
        if not self._current_data:
            return

        filepath, _ = QFileDialog.getSaveFileName(
            self,
            "Xuất CSV",
            f"history_{datetime.now():%Y%m%d_%H%M}.csv",
            "CSV Files (*.csv)",
        )
        if not filepath:
            return

        with open(filepath, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.writer(f)
            writer.writerow(["Thời Gian", "Cảm Biến", "Giá Trị", "Đơn Vị", "Raw"])
            for row in self._current_data:
                writer.writerow([row["time"], row["sensor"], row["value"], row["unit"], row["raw"]])
