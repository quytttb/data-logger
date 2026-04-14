"""Frozen-aware path resolution — works for both Python source and Nuitka compiled binary.

Khi chạy bình thường (python main.py):
    BASE_DIR = app/   (từ __file__ của module)

Khi chạy compiled (Nuitka standalone):
    sys.frozen = True → BASE_DIR = thư mục chứa binary DataLogger
    Ví dụ: /home/pi/data-logger/data-logger/dist/DataLogger.dist/

Có thể override từng dir bằng biến môi trường (hữu ích khi chạy qua systemd):
    DATALOGGER_DATA_DIR   → ghi đè DATA_DIR
    DATALOGGER_CONFIG_DIR → ghi đè CONFIG_DIR
    DATALOGGER_LOG_DIR    → ghi đè LOG_DIR
    DATALOGGER_QML_DIR    → ghi đè QML_DIR
"""

import os
import sys
from pathlib import Path

if getattr(sys, "frozen", False):
    # Nuitka standalone: sys.executable = /path/to/DataLogger.dist/DataLogger
    _BIN_DIR = Path(sys.executable).resolve().parent
else:
    # Python source: __file__ = app/core/_paths.py → parent.parent = app/
    _BIN_DIR = Path(__file__).resolve().parent.parent

DATA_DIR   = Path(os.environ.get("DATALOGGER_DATA_DIR",   str(_BIN_DIR / "data")))
CONFIG_DIR = Path(os.environ.get("DATALOGGER_CONFIG_DIR", str(_BIN_DIR / "config")))
LOG_DIR    = Path(os.environ.get("DATALOGGER_LOG_DIR",    str(_BIN_DIR / "logs")))
QML_DIR    = Path(os.environ.get("DATALOGGER_QML_DIR",    str(_BIN_DIR / "ui" / "qml")))
I18N_DIR   = Path(os.environ.get("DATALOGGER_I18N_DIR",   str(_BIN_DIR / "i18n")))

# Icon: PNG ưu tiên (taskbar/panel Linux thường cần pixmap, SVG hay lỗi); fallback SVG
APP_ICON_PNG = _BIN_DIR / "assets" / "app-icon.png"
APP_ICON_SVG = _BIN_DIR / "assets" / "app-icon.svg"


def app_icon_path() -> Path | None:
    """Đường dẫn file icon dùng cho QIcon / QML; None nếu không có asset."""
    if APP_ICON_PNG.is_file():
        return APP_ICON_PNG
    if APP_ICON_SVG.is_file():
        return APP_ICON_SVG
    return None


# Khớp data-logger.desktop (StartupWMClass + setDesktopFileName)
APP_DESKTOP_ID = "data-logger"


def argv_for_qt(argv: list[str]) -> list[str]:
    """Linux + python: Qt dùng argv[0] cho WM_CLASS — nếu là python/main.py shell gán icon CPython."""
    out = list(argv)
    if getattr(sys, "frozen", False) or not sys.platform.startswith("linux"):
        return out
    if out:
        out[0] = APP_DESKTOP_ID
    return out


# Đảm bảo các thư mục cần thiết tồn tại
DATA_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
