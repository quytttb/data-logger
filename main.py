"""Data Logger — Entry Point.

Khởi tạo QGuiApplication, Database và load Main.qml.
Giao diện QML được thiết kế theo triết lý "Precision Brutalism"
tối ưu màn hình công nghiệp 1024x600.
"""

import logging
import os
import sys
from pathlib import Path

from PySide6.QtCore import Qt, QTimer, QUrl
from PySide6.QtGui import QGuiApplication, QIcon, QPixmap
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow

from core._paths import (
    APP_DESKTOP_ID,
    I18N_DIR,
    LOG_DIR,
    QML_DIR,
    app_icon_path,
    argv_for_qt,
)
from core.database import init_db
from ui.tester_controller import TesterController
from ui.settings_controller import SettingsController
from ui.sensor_model import SensorListModel
from ui.dashboard_controller import DashboardController, DashboardModel
from ui.history_controller import HistoryController, HistoryModel
from ui.report_controller import ReportController
from ui.i18n_bridge import I18nBridge, install_locale

# === Logging Setup ===
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "app.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
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
    logger.info("Data Logger — Khởi động")
    logger.info("=" * 60)

    init_db()
    logger.info("Database initialized.")

    # Material theme cho tất cả QQC2 controls (CheckBox, ComboBox, SpinBox, etc.)
    _conf = QML_DIR / "qtquickcontrols2.conf"
    if _conf.is_file():
        os.environ.setdefault("QT_QUICK_CONTROLS_CONF", str(_conf))

    app = QGuiApplication(argv_for_qt(sys.argv))
    # applicationName khớp StartupWMClass / WM_CLASS (taskbar Linux); tiêu đề hiển thị vẫn "Data Logger" (QML + display name)
    app.setApplicationName(APP_DESKTOP_ID)
    app.setApplicationVersion("2.0.0")
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

    # Register Controllers (load config trước để lấy ngôn ngữ)
    settings_controller = SettingsController()
    settings_controller.load_config()
    install_locale(app, settings_controller.uiLocale, I18N_DIR)

    tester_controller = TesterController()
    sensor_model = SensorListModel()
    dashboard_model = DashboardModel()
    dashboard_controller = DashboardController(dashboard_model, tester_controller)
    history_model = HistoryModel()
    history_controller = HistoryController(history_model)
    report_controller = ReportController()

    # Khi danh sách sensor thay đổi → cập nhật ComboBox lịch sử + dashboard
    sensor_model.countChanged.connect(history_controller.load_sensors)
    sensor_model.countChanged.connect(dashboard_controller.refresh_sensors)

    engine.rootContext().setContextProperty("testerController", tester_controller)
    engine.rootContext().setContextProperty("settingsController", settings_controller)
    engine.rootContext().setContextProperty("sensorModel", sensor_model)
    engine.rootContext().setContextProperty("dashboardModel", dashboard_model)
    engine.rootContext().setContextProperty("dashboardController", dashboard_controller)
    engine.rootContext().setContextProperty("historyModel", history_model)
    engine.rootContext().setContextProperty("historyController", history_controller)
    engine.rootContext().setContextProperty("reportController", report_controller)

    i18n_bridge = I18nBridge(app, engine, I18N_DIR)
    engine.rootContext().setContextProperty("i18nBridge", i18n_bridge)

    def _on_ui_locale_changed() -> None:
        """Đổi ngôn ngữ ngay khi uiLocale đổi (ComboBox), không chỉ khi Lưu cấu hình."""
        install_locale(app, settings_controller.uiLocale, I18N_DIR)
        retranslate = getattr(engine, "retranslate", None)
        if callable(retranslate):
            retranslate()
        history_controller.load_sensors()
        dashboard_controller.refresh_status_display()

    settings_controller.uiLocaleChanged.connect(_on_ui_locale_changed)

    # Load Main.qml
    qml_file = QML_DIR / "Main.qml"
    logger.info("Loading QML: %s", qml_file)
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    roots = engine.rootObjects()
    if not roots:
        logger.error("Không thể load Main.qml — thoát.")
        sys.exit(1)

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

    app.aboutToQuit.connect(dashboard_controller.stop_polling_sync)
    app.aboutToQuit.connect(report_controller.stop_reporting)

    logger.info("QML loaded thành công. App đang chạy.")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
