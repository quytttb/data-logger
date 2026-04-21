"""UI DashboardWidget — Grid Card full-width cho 1024px."""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)


class SensorCard(QWidget):
    """Một ô hiển thị thông số cảm biến — thiết kế cho full-width."""

    def __init__(self, name: str, unit: str):
        super().__init__()
        self.setProperty("class", "SensorCard")
        self.setMinimumHeight(220)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 20, 24, 16)
        layout.setSpacing(4)

        # Tiêu đề
        self._lblName = QLabel(name.upper())
        self._lblName.setStyleSheet(
            "color: #8c90a0; font-weight: 800; font-size: 14px; letter-spacing: 2px;"
        )
        layout.addWidget(self._lblName)

        # Giá trị khổng lồ + Đơn vị
        val_row = QHBoxLayout()
        val_row.setSpacing(8)
        self._lblValue = QLabel("—")
        self._lblValue.setStyleSheet(
            "color: #e5e2e1; font-size: 72px; font-weight: 900;"
        )
        val_row.addWidget(self._lblValue)

        self._lblUnit = QLabel(unit)
        self._lblUnit.setStyleSheet("color: #558dff; font-size: 22px; font-weight: bold;")
        self._lblUnit.setAlignment(Qt.AlignmentFlag.AlignBottom)
        val_row.addWidget(self._lblUnit)
        val_row.addStretch()
        layout.addLayout(val_row)

        layout.addStretch()

        # Dòng dưới: RAW + Thời gian
        bot = QHBoxLayout()
        self._lblRaw = QLabel("RAW: —")
        self._lblRaw.setStyleSheet(
            "color: rgba(140,144,160,0.5); font-size: 12px; font-weight: bold; font-family: monospace;"
        )
        bot.addWidget(self._lblRaw)
        bot.addStretch()

        self._lblTime = QLabel("")
        self._lblTime.setStyleSheet(
            "color: rgba(140,144,160,0.5); font-size: 12px; font-weight: bold;"
        )
        bot.addWidget(self._lblTime)
        layout.addLayout(bot)

    def update_data(self, value: float | None, raw: int | None, recorded_at: str):
        if value is not None:
            self._lblValue.setText(f"{value:.2f}")
        else:
            self._lblValue.setText("ERR")
            self._lblValue.setStyleSheet("color: #ff5353; font-size: 72px; font-weight: 900;")

        self._lblRaw.setText(f"RAW: {raw if raw is not None else 'N/A'}")

        if isinstance(recorded_at, str) and "T" in recorded_at:
            self._lblTime.setText(f"⏱ {recorded_at.split('T')[1][:8]}")


class DashboardWidget(QWidget):
    """Tab Dashboard — Grid 2 cột cuộn dọc, full-width."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._cards: dict[int, SensorCard] = {}

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(16, 16, 16, 16)

        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll_area.setStyleSheet("background: transparent;")

        self.grid_widget = QWidget()
        self.grid_widget.setStyleSheet("background: transparent;")
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(16)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.grid_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        self.scroll_area.setWidget(self.grid_widget)
        main_layout.addWidget(self.scroll_area)

    def setup_sensors(self, sensors: list[dict]) -> None:
        # Clear
        for i in reversed(range(self.grid_layout.count())):
            w = self.grid_layout.itemAt(i).widget()
            if w:
                w.setParent(None)
        self._cards.clear()

        for idx, sensor in enumerate(sensors):
            row = idx // 2
            col = idx % 2
            card = SensorCard(sensor["name"], sensor.get("unit", ""))
            self.grid_layout.addWidget(card, row, col)
            self._cards[sensor["id"]] = card

    def update_values(self, data: dict) -> None:
        sensor_id = data["sensor_id"]
        if sensor_id in self._cards:
            self._cards[sensor_id].update_data(
                value=data.get("value"),
                raw=data.get("raw_value"),
                recorded_at=data.get("recorded_at", ""),
            )
