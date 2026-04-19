#!/usr/bin/env python3
"""E2E Integration Test — Full App on RPi Display.

Seeds the DB, launches the real QML GUI, runs through all tabs
with automated assertions, takes screenshots, and prints a summary.

Usage on RPi:
    cd /home/pi/data-logger/app && .venv/bin/python tests/test_e2e_app.py
"""

import os
import sys

# Trước mọi import PySide6/Qt — để X11/scrot đọc được framebuffer khi cần fallback.
os.environ.setdefault("QT_QUICK_BACKEND", "software")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import logging
from datetime import datetime, timedelta
from pathlib import Path

from sqlmodel import select

from core.database import init_db, get_session
from models.app_config import AppConfig
from models.sensor import Sensor
from models.sensor_data import SensorData

# ═══════════════════════════════════════════════════════════════
#  1. SEED DATABASE
# ═══════════════════════════════════════════════════════════════

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "datalogger.db"
DB_PATH.unlink(missing_ok=True)

init_db()

session = get_session()

cfg = AppConfig(
    station_code="E2E-001",
    station_name="Tram E2E Test",
    ftp_address="127.0.0.1",
    ftp_port=2222,
    ftp_username="testuser",
    ftp_password="",
    ftp_remote_path="/data",
    poll_interval=3,
    serial_port="/dev/ttyUSB0",
    serial_baudrate=9600,
    serial_bytesize=8,
    serial_parity="N",
    serial_stopbits=1,
)
session.add(cfg)

s1 = Sensor(
    name="Nhiet do", unit="°C", slave_id=1, register_address=0,
    register_type="input", data_type="int16", data_format="AB",
    coefficient="{}", report_index=1, active=True,
)
s2 = Sensor(
    name="Do pH", unit="pH", slave_id=2, register_address=1,
    register_type="input", data_type="int16", data_format="AB",
    coefficient="{}", report_index=2, active=True,
)
session.add(s1)
session.add(s2)
session.commit()
session.refresh(s1)
session.refresh(s2)

now = datetime.now()
for i in range(50):
    session.add(SensorData(
        sensor_id=s1.id, value=22.0 + i * 0.2,
        raw_value=220 + i * 2,
        recorded_at=now - timedelta(minutes=50 - i),
    ))
    session.add(SensorData(
        sensor_id=s2.id, value=6.8 + i * 0.01,
        raw_value=680 + i,
        recorded_at=now - timedelta(minutes=50 - i),
    ))
session.commit()
session.close()

print(f"[SEED] DB seeded: AppConfig E2E-001, 2 sensors, 100 sensor_data records")

# ═══════════════════════════════════════════════════════════════
#  2. LAUNCH APP (same as main.py)
# ═══════════════════════════════════════════════════════════════

from PySide6.QtCore import QObject, QElapsedTimer, QSize, QTimer, QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow

from core._paths import APP_DESKTOP_ID, app_icon_path, argv_for_qt

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

from ui.controllers.tester_controller import TesterController
from ui.controllers.settings_controller import SettingsController
from ui.models.sensor_list_model import SensorListModel
from ui.controllers.monitor_controller import MonitorController, MonitorModel
from ui.controllers.history_controller import HistoryController, HistoryModel
from ui.controllers.report_controller import ReportController

app = QGuiApplication(argv_for_qt(sys.argv))
app.setApplicationName(APP_DESKTOP_ID)
app.setApplicationVersion("2.0.0")
_disp = getattr(app, "setApplicationDisplayName", None)
if callable(_disp):
    _disp("Data Logger")
_e2e_icon = app_icon_path()
if _e2e_icon is not None:
    app.setWindowIcon(QIcon(str(_e2e_icon)))

engine = QQmlApplicationEngine()
app_icon_url = (
    QUrl.fromLocalFile(str(_e2e_icon.resolve())).toString()
    if _e2e_icon is not None
    else ""
)
engine.rootContext().setContextProperty("appIconUrl", app_icon_url)

tester_ctrl = TesterController()
settings_ctrl = SettingsController()
sensor_model = SensorListModel()
monitor_model = MonitorModel()
monitor_ctrl = MonitorController(monitor_model)
history_model = HistoryModel()
history_ctrl = HistoryController(history_model)
history_ctrl.attach_monitor(monitor_ctrl)
report_ctrl = ReportController()

engine.rootContext().setContextProperty("testerController", tester_ctrl)
engine.rootContext().setContextProperty("settingsController", settings_ctrl)
engine.rootContext().setContextProperty("sensorModel", sensor_model)
engine.rootContext().setContextProperty("monitorModel", monitor_model)
engine.rootContext().setContextProperty("monitorController", monitor_ctrl)
engine.rootContext().setContextProperty("historyModel", history_model)
engine.rootContext().setContextProperty("historyController", history_ctrl)
engine.rootContext().setContextProperty("reportController", report_ctrl)

QML_DIR = Path(__file__).resolve().parent.parent / "ui" / "qml"
engine.load(QUrl.fromLocalFile(str(QML_DIR / "Main.qml")))

if not engine.rootObjects():
    print("[FATAL] Cannot load Main.qml")
    sys.exit(1)

app.aboutToQuit.connect(monitor_ctrl.stop_polling)
app.aboutToQuit.connect(report_ctrl.stop_reporting)

# ═══════════════════════════════════════════════════════════════
#  3. TEST HARNESS
# ═══════════════════════════════════════════════════════════════

SCREENSHOT_DIR = Path(__file__).resolve().parent.parent / "data" / "screenshots"
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

passed = 0
failed = 0
window = engine.rootObjects()[0]


def check(name: str, condition: bool, detail: str = ""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  ✅ {name}")
    else:
        failed += 1
        print(f"  ❌ {name} — {detail}")


def _quick_window_from_root(root):
    """ApplicationWindow có thể là QQuickWindow / QQuickApplicationWindow; PySide6 đôi khi bọc là QWindow."""
    if isinstance(root, QQuickWindow):
        return root
    try:
        from PySide6.QtQuickControls2 import QQuickApplicationWindow

        if isinstance(root, QQuickApplicationWindow):
            return root
    except ImportError:
        pass
    try:
        import shiboken6

        ptr = shiboken6.getCppPointer(root)
        if ptr:
            w = shiboken6.wrapInstance(int(ptr[0]), QQuickWindow)
            if w is not None and callable(getattr(w, "grabWindow", None)):
                return w
    except Exception:
        pass
    return None


def _screenshot_grab_to_image(qw: QQuickWindow, path: Path) -> bool:
    """Async grabToImage — pump events (không dùng QEventLoop.exec lồng)."""
    item = qw.contentItem()
    if not isinstance(item, QQuickItem):
        return False
    state = {"ok": False, "finished": False}

    def on_done(result):
        try:
            im = result.image()
            if im is not None and not im.isNull():
                state["ok"] = bool(im.save(str(path)))
        finally:
            state["finished"] = True

    item.grabToImage(on_done, QSize())
    t = QElapsedTimer()
    t.start()
    while not state["finished"] and t.elapsed() < 8000:
        app.processEvents()
    return state["ok"]


def screenshot(filename: str):
    """Hướng Grok 1: instance QQuickWindow.grabWindow(); fallback grabToImage; cuối cùng scrot."""
    import subprocess

    path = SCREENSHOT_DIR / filename
    app.processEvents()
    try:
        window.raise_()
        window.requestActivate()
    except Exception:
        pass
    app.processEvents()

    qw = _quick_window_from_root(window)
    if qw is not None:
        try:
            img = qw.grabWindow()
            if img is not None and not img.isNull() and img.save(str(path)):
                print(f"  📸 {path}")
                return
        except Exception as e:
            print(f"  ⚠️  grabWindow: {e}")
        if _screenshot_grab_to_image(qw, path):
            print(f"  📸 {path}")
            return

    disp = os.environ.get("DISPLAY", ":0")
    try:
        subprocess.run(
            ["scrot", "-u", str(path)],
            env={**os.environ, "DISPLAY": disp},
            timeout=5,
            check=True,
            capture_output=True,
        )
        print(f"  📸 {path} (scrot)")
    except Exception as e:
        print(f"  ⚠️  Screenshot failed: {e}")


def find_stack_layout():
    """Find the StackLayout in the QObject tree by class name."""
    for child in window.findChildren(QObject):
        cls = child.metaObject().className()
        if "StackLayout" in cls:
            return child
    return None


def switch_tab(index: int):
    stack = find_stack_layout()
    if stack:
        stack.setProperty("currentIndex", index)


def close_all_popups():
    """Find and close any open Popup in the QML tree."""
    for child in window.findChildren(QObject):
        cls = child.metaObject().className()
        if "Popup" in cls or "QQuickPopup" in cls:
            if child.property("visible"):
                child.setProperty("visible", False)
    app.processEvents()


# ═══════════════════════════════════════════════════════════════
#  4. TEST STEPS — Chained via QTimer.singleShot
#
#  Each step finishes by scheduling the NEXT step so that
#  blocking calls (e.g. stop_polling) don't cause race conditions.
# ═══════════════════════════════════════════════════════════════

def step0_app_launch():
    print(f"\n{'='*60}\n  Step 0 — App Launch\n{'='*60}")
    check("Root objects loaded", len(engine.rootObjects()) > 0)
    check("Window title", window.title() == "Data Logger",
          f"got: {window.title()}")
    check("Window width", window.width() == 1024, f"got: {window.width()}")
    check("Window height >= 480", window.height() >= 480, f"got: {window.height()}")
    check("StackLayout found", find_stack_layout() is not None)
    screenshot("01_app_launch.png")

    QTimer.singleShot(1000, step1_settings_tab)


def step1_settings_tab():
    print(f"\n{'='*60}\n  Step 1 — Settings Tab (CÀI ĐẶT)\n{'='*60}")
    switch_tab(3)
    settings_ctrl.load_config()
    sensor_model.refresh()

    QTimer.singleShot(500, _step1_verify)


def _step1_verify():
    check("stationCode == E2E-001",
          settings_ctrl.stationCode == "E2E-001",
          f"got: {settings_ctrl.stationCode}")
    check("stationName == Tram E2E Test",
          settings_ctrl.stationName == "Tram E2E Test",
          f"got: {settings_ctrl.stationName}")
    check("serialPort == /dev/ttyUSB0",
          settings_ctrl.serialPort == "/dev/ttyUSB0",
          f"got: {settings_ctrl.serialPort}")
    check("serialBaudrate == 9600",
          settings_ctrl.serialBaudrate == 9600,
          f"got: {settings_ctrl.serialBaudrate}")
    check("pollInterval == 3",
          settings_ctrl.pollInterval == 3,
          f"got: {settings_ctrl.pollInterval}")
    check("sensorModel.rowCount == 2",
          sensor_model.rowCount() == 2,
          f"got: {sensor_model.rowCount()}")
    screenshot("02_settings.png")

    QTimer.singleShot(500, step2_history_tab)


def step2_history_tab():
    print(f"\n{'='*60}\n  Step 2 — History Tab (LỊCH SỬ)\n{'='*60}")
    switch_tab(2)
    today = now.strftime("%d/%m/%Y")
    history_ctrl.search(today, today)

    QTimer.singleShot(2000, _step2_verify)


def _step2_verify():
    check("isLoading done",
          history_ctrl.isLoading == False)
    check("recordCount > 0",
          history_ctrl.recordCount > 0,
          f"got: {history_ctrl.recordCount}")
    check("historyModel rows > 0",
          history_model.rowCount() > 0,
          f"got: {history_model.rowCount()}")
    screenshot("03_history.png")

    QTimer.singleShot(500, step3_csv_export)


def step3_csv_export():
    print(f"\n{'='*60}\n  Step 3 — CSV Export\n{'='*60}")
    csv_path = SCREENSHOT_DIR.parent / "e2e_export.csv"
    history_ctrl.export_csv(str(csv_path))

    check("CSV file created", csv_path.exists())
    if csv_path.exists():
        with open(csv_path, "rb") as f:
            bom = f.read(3)
        check("CSV UTF-8 BOM", bom == b"\xef\xbb\xbf")
        content = csv_path.read_text(encoding="utf-8-sig")
        lines = content.strip().split("\n")
        check("CSV has header + data", len(lines) > 1, f"lines: {len(lines)}")
        check("CSV header correct",
              "Thời gian" in lines[0] and "Cảm biến" in lines[0])

    close_all_popups()
    QTimer.singleShot(500, step4_monitor_start)


def step4_monitor_start():
    print(f"\n{'='*60}\n  Step 4 — Dashboard Start Polling\n{'='*60}")
    close_all_popups()
    switch_tab(1)
    monitor_ctrl.start_polling()
    check("isPolling after start",
          monitor_ctrl.isPolling == True)
    check("monitorModel rows == 2",
          monitor_model.rowCount() == 2,
          f"got: {monitor_model.rowCount()}")
    check("statusText contains THU THẬP",
          "Monitoring" in monitor_ctrl.statusText,
          f"got: {monitor_ctrl.statusText}")

    QTimer.singleShot(5000, _step4_screenshot)


def _step4_screenshot():
    close_all_popups()
    screenshot("04_monitor_polling.png")
    QTimer.singleShot(500, step5_monitor_stop)


def step5_monitor_stop():
    print(f"\n{'='*60}\n  Step 5 — Dashboard Stop Polling\n{'='*60}")
    close_all_popups()
    monitor_ctrl.stop_polling()
    check("isPolling after stop",
          monitor_ctrl.isPolling == False)
    check("statusText contains DỪNG",
          "Stopped" in monitor_ctrl.statusText,
          f"got: {monitor_ctrl.statusText}")
    close_all_popups()
    screenshot("05_monitor_stopped.png")

    QTimer.singleShot(500, step6_tester_tab)


def step6_tester_tab():
    print(f"\n{'='*60}\n  Step 6 — Tester Tab (DÒ MODBUS)\n{'='*60}")
    switch_tab(0)

    QTimer.singleShot(500, _step6_screenshot)


def _step6_screenshot():
    close_all_popups()
    screenshot("06_tester.png")
    QTimer.singleShot(500, step7_summary)


def step7_summary():
    total = passed + failed
    print(f"\n{'='*60}")
    print(f"  E2E KẾT QUẢ: {passed}/{total} PASSED, {failed} FAILED")
    print(f"  Screenshots: {SCREENSHOT_DIR}")
    print(f"{'='*60}\n")
    app.exit(0 if failed == 0 else 1)


# ═══════════════════════════════════════════════════════════════
#  5. START
# ═══════════════════════════════════════════════════════════════

QTimer.singleShot(2000, step0_app_launch)

print(f"\n[APP] Launching Data Logger E2E Test...")
print(f"[APP] Screenshots will be saved to: {SCREENSHOT_DIR}")
print(f"[APP] Test will auto-quit after all steps complete.\n")

sys.exit(app.exec())
