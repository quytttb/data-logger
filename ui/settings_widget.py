"""UI SettingsWidget — Tab Cài đặt, full-width form."""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
    QFrame,
)

from sqlmodel import select, update

from core.crypto import decrypt, encrypt
from core.database import get_session
from models.app_config import AppConfig
from models.sensor import Sensor


class SettingsWidget(QWidget):
    """Tab Cài đặt — form lớn, cuộn dọc, nút Lưu dính đáy."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._setup_ui()

    def _setup_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # Vùng cuộn
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(16)

        # === 1. Thông tin Trạm (1 hàng ngang) ===
        station_group = QGroupBox("THÔNG TIN TRẠM")
        sg = QHBoxLayout(station_group)
        sg.setSpacing(12)

        v1 = QVBoxLayout()
        v1.addWidget(QLabel("Mã Trạm"))
        self._station_code = QLineEdit()
        self._station_code.setPlaceholderText("VD: TRAM-BD-001")
        v1.addWidget(self._station_code)
        sg.addLayout(v1, 2)

        v2 = QVBoxLayout()
        v2.addWidget(QLabel("Tên Trạm"))
        self._station_name = QLineEdit()
        v2.addWidget(self._station_name)
        sg.addLayout(v2, 3)

        v3 = QVBoxLayout()
        v3.addWidget(QLabel("Polling (s)"))
        self._poll_interval = QSpinBox()
        self._poll_interval.setRange(1, 120)
        self._poll_interval.setValue(3)
        v3.addWidget(self._poll_interval)
        sg.addLayout(v3, 1)

        layout.addWidget(station_group)

        # === 2. FTP (2 hàng grid) ===
        ftp_group = QGroupBox("CẤU HÌNH sFTP")
        grid = QGridLayout(ftp_group)
        grid.setSpacing(8)

        grid.addWidget(QLabel("IP/Domain"), 0, 0)
        self._ftp_address = QLineEdit()
        grid.addWidget(self._ftp_address, 0, 1)

        grid.addWidget(QLabel("Port"), 0, 2)
        self._ftp_port = QSpinBox()
        self._ftp_port.setRange(1, 65535)
        self._ftp_port.setValue(22)
        grid.addWidget(self._ftp_port, 0, 3)

        grid.addWidget(QLabel("User"), 1, 0)
        self._ftp_username = QLineEdit()
        grid.addWidget(self._ftp_username, 1, 1)

        grid.addWidget(QLabel("Pass (AES)"), 1, 2)
        self._ftp_password = QLineEdit()
        self._ftp_password.setEchoMode(QLineEdit.EchoMode.Password)
        grid.addWidget(self._ftp_password, 1, 3)

        grid.addWidget(QLabel("Remote Path"), 2, 0)
        self._ftp_remote_path = QLineEdit()
        self._ftp_remote_path.setPlaceholderText("/data/")
        grid.addWidget(self._ftp_remote_path, 2, 1, 1, 3)

        layout.addWidget(ftp_group)

        # === 3. Bảng Cảm biến ===
        sensor_group = QGroupBox("CẢM BIẾN MODBUS")
        sl = QVBoxLayout(sensor_group)

        btn_add = QPushButton("+ THÊM CẢM BIẾN")
        btn_add.clicked.connect(self._add_sensor_row)
        sl.addWidget(btn_add, alignment=Qt.AlignmentFlag.AlignLeft)

        self._sensor_table = QTableWidget()
        self._sensor_table.setColumnCount(9)
        self._sensor_table.setHorizontalHeaderLabels([
            "Tên", "Đ.Vị", "Slave", "Reg",
            "Type", "Data", "Endian", "Hệ Số", "TT10"
        ])
        h = self._sensor_table.horizontalHeader()
        h.setMinimumHeight(36)
        h.setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        h.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)

        self._sensor_table.verticalHeader().setDefaultSectionSize(48)
        self._sensor_table.setMinimumHeight(200)
        sl.addWidget(self._sensor_table)

        layout.addWidget(sensor_group)

        scroll.setWidget(content)
        outer.addWidget(scroll)

        # Nút Lưu cố định dưới cùng
        bot_bar = QWidget()
        bot_bar.setFixedHeight(56)
        bot_bar.setStyleSheet("background: #131313; border-top: 1px solid #424655;")
        bot_layout = QHBoxLayout(bot_bar)
        bot_layout.setContentsMargins(16, 8, 16, 8)

        btn_save = QPushButton("💾  LƯU CẤU HÌNH")
        btn_save.setProperty("class", "PrimaryAction")
        btn_save.setMinimumHeight(40)
        btn_save.setStyleSheet("font-size: 18px; font-weight: bold;")
        btn_save.clicked.connect(self._save_config)
        bot_layout.addWidget(btn_save)

        outer.addWidget(bot_bar)

    # ──── Data I/O ────

    def load_config(self) -> None:
        session = get_session()
        try:
            config = session.exec(select(AppConfig)).first()
            if config:
                self._station_code.setText(config.station_code)
                self._station_name.setText(config.station_name)
                self._ftp_address.setText(config.ftp_address)
                self._ftp_port.setValue(config.ftp_port)
                self._ftp_username.setText(config.ftp_username)
                self._ftp_remote_path.setText(config.ftp_remote_path)
                self._poll_interval.setValue(config.poll_interval)
                if config.ftp_password:
                    try:
                        self._ftp_password.setText(decrypt(config.ftp_password))
                    except Exception:
                        self._ftp_password.setText("")

            sensors = session.exec(select(Sensor).where(Sensor.active == True)).all()  # noqa: E712
            self._sensor_table.setRowCount(len(sensors))
            for row, s in enumerate(sensors):
                self._sensor_table.setItem(row, 0, QTableWidgetItem(s.name))
                self._sensor_table.setItem(row, 1, QTableWidgetItem(s.unit))
                self._sensor_table.setItem(row, 2, QTableWidgetItem(str(s.slave_id)))
                self._sensor_table.setItem(row, 3, QTableWidgetItem(str(s.register_address)))
                self._set_combo(row, 4, ["holding", "input"], s.register_type)
                self._set_combo(row, 5, ["int16", "uint16", "float32"], s.data_type)
                self._set_combo(row, 6, ["AB", "BA", "ABCD", "CDAB"], s.data_format)
                self._sensor_table.setItem(row, 7, QTableWidgetItem(s.coefficient or "{}"))
                self._sensor_table.setItem(row, 8, QTableWidgetItem(str(s.report_index)))
        finally:
            session.close()

    def _set_combo(self, row: int, col: int, items: list[str], current: str):
        combo = QComboBox()
        combo.addItems(items)
        combo.setCurrentText(current)
        self._sensor_table.setCellWidget(row, col, combo)

    def _add_sensor_row(self) -> None:
        row = self._sensor_table.rowCount()
        self._sensor_table.insertRow(row)
        self._set_combo(row, 4, ["holding", "input"], "holding")
        self._set_combo(row, 5, ["int16", "uint16", "float32"], "int16")
        self._set_combo(row, 6, ["AB", "BA", "ABCD", "CDAB"], "AB")
        self._sensor_table.setItem(row, 7, QTableWidgetItem("{}"))
        self._sensor_table.setItem(row, 8, QTableWidgetItem("0"))

    def _save_config(self) -> None:
        session = get_session()
        try:
            config = session.exec(select(AppConfig)).first()
            if not config:
                config = AppConfig()
                session.add(config)

            config.station_code = self._station_code.text().strip()
            config.station_name = self._station_name.text().strip()
            config.ftp_address = self._ftp_address.text().strip()
            config.ftp_port = self._ftp_port.value()
            config.ftp_username = self._ftp_username.text().strip()
            config.ftp_remote_path = self._ftp_remote_path.text().strip()
            config.poll_interval = self._poll_interval.value()

            pwd = self._ftp_password.text()
            if pwd:
                config.ftp_password = encrypt(pwd)

            session.exec(update(Sensor).values(active=False))

            for row in range(self._sensor_table.rowCount()):
                name = self._cell(row, 0)
                if not name:
                    continue
                session.add(Sensor(
                    name=name,
                    unit=self._cell(row, 1),
                    slave_id=int(self._cell(row, 2) or "1"),
                    register_address=int(self._cell(row, 3) or "0"),
                    register_type=self._combo(row, 4),
                    data_type=self._combo(row, 5),
                    data_format=self._combo(row, 6),
                    coefficient=self._cell(row, 7) or "{}",
                    report_index=int(self._cell(row, 8) or "0"),
                    active=True,
                ))

            session.commit()
            QMessageBox.information(self, "OK", "Đã lưu! Khởi động lại app để áp dụng.")
        except Exception as e:
            session.rollback()
            QMessageBox.critical(self, "LỖI", str(e))
        finally:
            session.close()

    def _cell(self, row: int, col: int) -> str:
        item = self._sensor_table.item(row, col)
        return item.text().strip() if item else ""

    def _combo(self, row: int, col: int) -> str:
        w = self._sensor_table.cellWidget(row, col)
        return w.currentText() if isinstance(w, QComboBox) else ""
