"""Data Logger — Entry Point.

Khởi tạo QGuiApplication, Database và load Main.qml.
Giao diện QML được thiết kế theo triết lý "Precision Brutalism"
tối ưu màn hình công nghiệp 1024x600.
"""
# ruff: noqa: E402

import logging
import os
import sys
from pathlib import Path

from core.qt_qml_bootstrap import ensure_qt_qml_import_path

ensure_qt_qml_import_path()

from PySide6.QtCore import Qt, QTimer, QUrl
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow

from core._paths import (
    APP_DESKTOP_ID,
    QML_DIR,
    app_icon_path,
    argv_for_qt,
)
from core._version import __version__ as _APP_VERSION
from core.database import init_db
from core.txt_generator import cleanup_old_report_files
from ui.controllers.tester_controller import TesterController
from ui.controllers.settings_controller import SettingsController
from ui.models.sensor_list_model import SensorListModel
from ui.controllers.monitor_controller import MonitorController, MonitorModel
from ui.controllers.history_controller import HistoryController, HistoryModel
from ui.controllers.report_controller import ReportController
from core.log_setup import setup_logging

# === Logging Setup ===
setup_logging()
logger = logging.getLogger("datalogger")


def _window_icon(path: Path) -> QIcon:
    """QIcon cho taskbar Linux: PNG nạp nhiều kích thước (NET_WM_ICON); SVG dùng đường dẫn."""
    if path.suffix.lower() != ".png":
        return QIcon(str(path))
    pix = QPixmap(str(path))
    if pix.isNull():
        return QIcon(str(path))
    icon = QIcon()
    mode = Qt.AspectRatioMode.KeepAspectRatio
    xform = Qt.TransformationMode.SmoothTransformation
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        icon.addPixmap(pix.scaled(size, size, mode, xform))
    return icon


def main():
    """Hàm chính khởi động ứng dụng."""
    logger.info("=" * 60)
    logger.info("Data Logger — Starting")
    logger.info("=" * 60)

    init_db()
    logger.info("Database initialized.")

    cleanup_old_report_files()

    # Material theme cho tất cả QQC2 controls (CheckBox, ComboBox, SpinBox, etc.)
    _conf = QML_DIR / "qtquickcontrols2.conf"
    if _conf.is_file():
        os.environ.setdefault("QT_QUICK_CONTROLS_CONF", str(_conf))

    app = QApplication(argv_for_qt(sys.argv))
    # applicationName khớp StartupWMClass / WM_CLASS (taskbar Linux); tiêu đề hiển thị vẫn "Data Logger" (QML + display name)
    app.setApplicationName(APP_DESKTOP_ID)
    app.setApplicationVersion(_APP_VERSION)
    disp = getattr(app, "setApplicationDisplayName", None)
    if callable(disp):
        disp("Data Logger")
    # Khớp ~/.local/share/applications/data-logger.desktop (basename, không có .desktop)
    app.setDesktopFileName(APP_DESKTOP_ID)
    _icon_file = app_icon_path()
    _app_icon = QIcon()
    if _icon_file is not None:
        _app_icon = _window_icon(_icon_file)
        app.setWindowIcon(_app_icon)

    engine = QQmlApplicationEngine()
    app_icon_url = (
        QUrl.fromLocalFile(str(_icon_file.resolve())).toString()
        if _icon_file is not None
        else ""
    )
    engine.rootContext().setContextProperty("appIconUrl", app_icon_url)

    # Register Controllers
    settings_controller = SettingsController()
    settings_controller.load_config()

    tester_controller = TesterController()
    sensor_model = SensorListModel()
    monitor_model = MonitorModel()
    monitor_controller = MonitorController(monitor_model, tester_controller)
    history_model = HistoryModel()
    history_controller = HistoryController(history_model)
    history_controller.attach_monitor(monitor_controller)
    report_controller = ReportController()

    # Khi danh sách sensor thay đổi → cập nhật ComboBox lịch sử + monitor
    sensor_model.countChanged.connect(history_controller.load_sensors)
    sensor_model.countChanged.connect(monitor_controller.refresh_sensors)
    # Forward FTP heartbeats to MonitorController Watchdog
    report_controller.workerHeartbeat.connect(monitor_controller.register_heartbeat)

    engine.rootContext().setContextProperty("testerController", tester_controller)
    engine.rootContext().setContextProperty("settingsController", settings_controller)
    engine.rootContext().setContextProperty("sensorModel", sensor_model)
    engine.rootContext().setContextProperty("monitorModel", monitor_model)
    engine.rootContext().setContextProperty("monitorController", monitor_controller)
    engine.rootContext().setContextProperty("historyModel", history_model)
    engine.rootContext().setContextProperty("historyController", history_controller)
    engine.rootContext().setContextProperty("reportController", report_controller)

    # Load Main.qml
    qml_file = QML_DIR / "Main.qml"
    logger.info("Loading QML: %s", qml_file)
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    roots = engine.rootObjects()
    if not roots:
        logger.error("Failed to load Main.qml — exiting.")
        sys.exit(1)

    # Load sensor list from DB → triggers countChanged → updates Monitor + History
    sensor_model.refresh()

    # ApplicationWindow (QML) không kế thừa icon từ QGuiApplication trên nhiều WM Linux
    if _app_icon and not _app_icon.isNull():
        for obj in roots:
            if isinstance(obj, QQuickWindow):
                obj.setIcon(_app_icon)
                break
        else:
            setter = getattr(roots[0], "setIcon", None)
            if callable(setter):
                setter(_app_icon)

        def _reapply_icons() -> None:
            if _app_icon.isNull():
                return
            for w in app.topLevelWindows():
                if isinstance(w, QQuickWindow):
                    w.setIcon(_app_icon)

        QTimer.singleShot(0, _reapply_icons)

    # Auto-start FTP worker nếu server_active = True trong DB
    def _start_ftp_if_active():
        try:
            from sqlmodel import select as _sel
            from core.database import get_session as _gs
            from models.app_config import AppConfig as _AC
            _s = _gs()
            _cfg = _s.exec(_sel(_AC)).first()
            if _cfg and _cfg.server_active:
                report_controller.start_reporting()
                logger.info("FTP auto-started (server_active=True).")
            _s.close()
        except Exception as _e:
            logger.warning("Could not auto-start FTP: %s", _e)

    def _restart_ftp_on_save():
        report_controller.stop_reporting()
        QTimer.singleShot(500, _start_ftp_if_active)

    _start_ftp_if_active()
    settings_controller.configSaved.connect(_restart_ftp_on_save)

    # Tự động start monitoring khi khởi động app
    QTimer.singleShot(1000, monitor_controller.start_polling)

    app.aboutToQuit.connect(monitor_controller.stop_polling_sync)
    app.aboutToQuit.connect(report_controller.stop_reporting)

    logger.info("QML loaded successfully. Application running.")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
