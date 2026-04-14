"""Cài đặt QTranslator + gọi QQmlEngine.retranslate() khi đổi ngôn ngữ."""

from __future__ import annotations

import logging
from pathlib import Path

from PySide6.QtCore import QObject, QTranslator, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

logger = logging.getLogger(__name__)

_translator = QTranslator()


def install_locale(app: QGuiApplication, locale: str, qm_dir: Path) -> None:
    """Cài translator cho locale (en = không tải .qm)."""
    app.removeTranslator(_translator)
    locale = (locale or "vi").lower()
    if locale not in ("en", "vi"):
        locale = "vi"
    if locale == "vi":
        qm = qm_dir / "data_logger_vi.qm"
        if qm.is_file():
            if _translator.load(str(qm)):
                app.installTranslator(_translator)
                logger.info("Loaded translator: %s", qm)
            else:
                logger.warning("Failed to load QTranslator from %s", qm)
        else:
            logger.warning("Missing translation file: %s", qm)
    else:
        logger.info("UI locale=en (no translation file)")


class I18nBridge(QObject):
    """Exposed to QML as i18nBridge — đổi ngôn ngữ sau khi đã load QML."""

    def __init__(self, app: QGuiApplication, engine: QQmlApplicationEngine, qm_dir: Path, parent=None):
        super().__init__(parent)
        self._app = app
        self._engine = engine
        self._qm_dir = qm_dir

    @Slot(str)
    def setLocale(self, locale: str) -> None:
        install_locale(self._app, locale, self._qm_dir)
        rt = getattr(self._engine, "retranslate", None)
        if callable(rt):
            rt()
