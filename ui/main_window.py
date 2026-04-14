"""UI MainWindow — Controller với Tab Bar ngang phía trên (tối ưu 1024x600)."""

import logging
from datetime import datetime

from PySide6.QtCore import QThread, Slot, QTimer, Qt
from PySide6.QtGui import QCloseEvent
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QPushButton,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from sqlmodel import select

from core.database import get_session
from models.app_config import AppConfig
from models.sensor import Sensor
from ui.dashboard_widget import DashboardWidget
from ui.history_widget import HistoryWidget
from ui.settings_widget import SettingsWidget
from workers.database_worker import DatabaseWorker
from workers.modbus_worker import ModbusWorker
from workers.ftp_worker import FtpWorker

logger = logging.getLogger("datalogger.main")


class MainWindow(QMainWindow):
    """Cửa sổ chính 1024x600 — Tab Bar ngang, tận dụng toàn bộ chiều rộng."""

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Data Logger")

        self._thread_modbus = None
        self._thread_db = None
        self._thread_ftp = None
        self._modbus_worker = None
        self._db_worker = None
        self._ftp_worker = None

        self._setup_ui()
        self._load_config_and_start()

        self._clock_timer = QTimer(self)
        self._clock_timer.timeout.connect(self._update_clock)
        self._clock_timer.start(1000)

    def _setup_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # ═══════════════════════════════════════════
        # HEADER BAR (48px) — Brand + Status + Clock
        # ═══════════════════════════════════════════
        header = QWidget()
        header.setObjectName("Topbar")
        header.setFixedHeight(48)
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(16, 0, 16, 0)
        header_layout.setSpacing(12)

        # Tên app
        brand = QLabel("⬡ DATALOGGER")
        brand.setStyleSheet("font-size: 18px; font-weight: 900; color: #b0c6ff; letter-spacing: 2px;")
        header_layout.addWidget(brand)

        # Tên trạm
        self._station_label = QLabel("")
        self._station_label.setStyleSheet(
            "color: #8c90a0; background: #1c1b1b; padding: 4px 12px; border-radius: 6px; font-size: 13px;"
        )
        header_layout.addWidget(self._station_label)

        header_layout.addStretch()

        # Trạng thái hệ thống
        self._status_dot = QLabel("●")
        self._status_dot.setStyleSheet("color: #7dffa2; font-size: 20px;")
        header_layout.addWidget(self._status_dot)

        self._status_label = QLabel("SYSTEM OK")
        self._status_label.setStyleSheet(
            "color: #7dffa2; font-weight: 800; font-size: 13px; letter-spacing: 2px;"
        )
        header_layout.addWidget(self._status_label)

        header_layout.addSpacing(16)

        # Đồng hồ
        self._clock_label = QLabel("00:00:00")
        self._clock_label.setStyleSheet(
            "color: #b0c6ff; font-size: 18px; font-weight: bold; font-family: monospace;"
        )
        header_layout.addWidget(self._clock_label)

        main_layout.addWidget(header)

        # ═══════════════════════════════════════════
        # TAB BAR (44px) — 3 nút bấm ngang
        # ═══════════════════════════════════════════
        tab_bar = QWidget()
        tab_bar.setStyleSheet("background-color: #1c1b1b;")
        tab_bar.setFixedHeight(44)
        tab_layout = QHBoxLayout(tab_bar)
        tab_layout.setContentsMargins(0, 0, 0, 0)
        tab_layout.setSpacing(0)

        self._btn_dash = self._make_tab_btn("❖  TỔNG QUAN", checked=True)
        self._btn_hist = self._make_tab_btn("📋  LỊCH SỬ")
        self._btn_set = self._make_tab_btn("⚙  CÀI ĐẶT")

        tab_layout.addWidget(self._btn_dash)
        tab_layout.addWidget(self._btn_hist)
        tab_layout.addWidget(self._btn_set)

        self._btn_dash.clicked.connect(lambda: self._switch_tab(0))
        self._btn_hist.clicked.connect(lambda: self._switch_tab(1))
        self._btn_set.clicked.connect(lambda: self._switch_tab(2))

        main_layout.addWidget(tab_bar)

        # ═══════════════════════════════════════════
        # CONTENT AREA (508px) — full width 1024px
        # ═══════════════════════════════════════════
        self._stack = QStackedWidget()
        self._dashboard = DashboardWidget()
        self._history = HistoryWidget()
        self._settings = SettingsWidget()

        self._stack.addWidget(self._dashboard)
        self._stack.addWidget(self._history)
        self._stack.addWidget(self._settings)

        main_layout.addWidget(self._stack)

    def _make_tab_btn(self, text: str, checked: bool = False) -> QPushButton:
        """Tạo 1 nút tab ngang."""
        btn = QPushButton(text)
        btn.setCheckable(True)
        btn.setChecked(checked)
        btn.setFixedHeight(44)
        btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                color: rgba(176, 198, 255, 0.5);
                border: none;
                border-bottom: 3px solid transparent;
                font-size: 15px;
                font-weight: bold;
                letter-spacing: 1px;
                padding: 0 24px;
            }
            QPushButton:hover {
                color: #b0c6ff;
                background: rgba(42, 47, 56, 0.5);
            }
            QPushButton:checked {
                color: #b0c6ff;
                border-bottom: 3px solid #558dff;
            }
        """)
        return btn

    def _switch_tab(self, index: int) -> None:
        self._btn_dash.setChecked(index == 0)
        self._btn_hist.setChecked(index == 1)
        self._btn_set.setChecked(index == 2)
        self._stack.setCurrentIndex(index)

    def _update_clock(self):
        self._clock_label.setText(datetime.now().strftime("%H:%M:%S"))

    def _load_config_and_start(self) -> None:
        session = get_session()
        try:
            config = session.exec(select(AppConfig)).first()
            sensors = session.exec(select(Sensor).where(Sensor.active == True)).all()  # noqa: E712

            if config and config.station_name:
                self._station_label.setText(f"{config.station_code} — {config.station_name}")

            sensor_list = [
                {
                    "id": s.id, "name": s.name, "unit": s.unit,
                    "slave_id": s.slave_id, "register_address": s.register_address,
                    "register_type": s.register_type, "data_type": s.data_type,
                    "data_format": s.data_format, "coefficient": s.coefficient,
                } for s in sensors
            ]

            if sensor_list:
                self._dashboard.setup_sensors(sensor_list)
                self._setup_workers(sensor_list, config)
            else:
                self._set_status("NO CONFIG", "#ffd740")

            self._settings.load_config()
        finally:
            session.close()

    def _set_status(self, text: str, color: str):
        self._status_label.setText(text)
        self._status_label.setStyleSheet(
            f"color: {color}; font-weight: 800; font-size: 13px; letter-spacing: 2px;"
        )
        self._status_dot.setStyleSheet(f"color: {color}; font-size: 20px;")

    def _setup_workers(self, sensors: list[dict], config: AppConfig) -> None:
        self._thread_db = QThread()
        self._db_worker = DatabaseWorker()
        self._db_worker.moveToThread(self._thread_db)
        self._thread_db.started.connect(self._db_worker.run)
        self._db_worker.db_error.connect(lambda e: logger.error(e))
        self._thread_db.start()

        self._thread_modbus = QThread()
        self._modbus_worker = ModbusWorker(port="/dev/ttyUSB0")
        self._modbus_worker.set_sensors(sensors)
        self._modbus_worker.moveToThread(self._thread_modbus)
        self._thread_modbus.started.connect(self._modbus_worker.run)
        self._modbus_worker.data_ready.connect(self._on_data_ready)
        self._modbus_worker.modbus_error.connect(self._on_modbus_error)
        self._thread_modbus.start()

        self._thread_ftp = QThread()
        self._ftp_worker = FtpWorker(interval_minutes=5)
        self._ftp_worker.moveToThread(self._thread_ftp)
        self._thread_ftp.started.connect(self._ftp_worker.run)
        self._ftp_worker.ftp_status.connect(self._on_ftp_status)
        self._thread_ftp.start()

        self._set_status("SYSTEM OK", "#7dffa2")

    @Slot(dict)
    def _on_data_ready(self, data: dict) -> None:
        self._dashboard.update_values(data)
        if self._db_worker:
            self._db_worker.enqueue(data)

    @Slot(str)
    def _on_modbus_error(self, error: str) -> None:
        self._set_status("MODBUS ALARM", "#ff5353")

    @Slot(str)
    def _on_ftp_status(self, status: str) -> None:
        if status.startswith("FAIL") or status.startswith("ERROR"):
            self._set_status("FTP FAIL", "#ffd740")

    def closeEvent(self, event: QCloseEvent) -> None:
        if self._modbus_worker: self._modbus_worker.stop()
        if self._db_worker: self._db_worker.stop()
        if self._ftp_worker: self._ftp_worker.stop()
        for t in [self._thread_modbus, self._thread_db, self._thread_ftp]:
            if t and t.isRunning():
                t.quit()
                t.wait(2000)
        event.accept()
