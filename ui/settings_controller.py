"""M2 — SettingsController: load / save AppConfig (1 dòng) từ SQLite.

FTP password được encrypt bằng Fernet trước khi lưu DB,
và decrypt khi load lên QML.
"""

import logging

from PySide6.QtCore import QObject, Property, Signal, Slot
from sqlmodel import select

from core.crypto import decrypt, encrypt
from core.database import get_session
from models.app_config import AppConfig

logger = logging.getLogger(__name__)


class SettingsController(QObject):
    configLoaded = Signal()
    configSaved = Signal()
    uiLocaleChanged = Signal()
    messageSent = Signal(str, str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._cfg = AppConfig()

    # ── Properties exposed to QML ──────────────────────────────────────────

    @Property(str, notify=configLoaded)
    def stationCode(self):
        return self._cfg.station_code

    @stationCode.setter
    def stationCode(self, v):
        self._cfg.station_code = v

    @Property(str, notify=configLoaded)
    def stationName(self):
        return self._cfg.station_name

    @stationName.setter
    def stationName(self, v):
        self._cfg.station_name = v

    @Property(str, notify=configLoaded)
    def ftpAddress(self):
        return self._cfg.ftp_address

    @ftpAddress.setter
    def ftpAddress(self, v):
        self._cfg.ftp_address = v

    @Property(int, notify=configLoaded)
    def ftpPort(self):
        return self._cfg.ftp_port

    @ftpPort.setter
    def ftpPort(self, v):
        self._cfg.ftp_port = v

    @Property(str, notify=configLoaded)
    def ftpUsername(self):
        return self._cfg.ftp_username

    @ftpUsername.setter
    def ftpUsername(self, v):
        self._cfg.ftp_username = v

    @Property(str, notify=configLoaded)
    def ftpRemotePath(self):
        return self._cfg.ftp_remote_path

    @ftpRemotePath.setter
    def ftpRemotePath(self, v):
        self._cfg.ftp_remote_path = v

    @Property(int, notify=configLoaded)
    def pollInterval(self):
        return self._cfg.poll_interval

    @pollInterval.setter
    def pollInterval(self, v):
        self._cfg.poll_interval = v

    @Property(str, notify=configLoaded)
    def ftpPassword(self):
        raw = self._cfg.ftp_password
        if not raw:
            return ""
        try:
            return decrypt(raw)
        except Exception:
            return raw

    @ftpPassword.setter
    def ftpPassword(self, value):
        self._cfg.ftp_password = encrypt(value) if value else ""

    # ── Serial Properties ──────────────────────────────────────────────────

    @Property(str, notify=configLoaded)
    def serialPort(self):
        return self._cfg.serial_port

    @serialPort.setter
    def serialPort(self, v):
        self._cfg.serial_port = v

    @Property(int, notify=configLoaded)
    def serialBaudrate(self):
        return self._cfg.serial_baudrate

    @serialBaudrate.setter
    def serialBaudrate(self, v):
        self._cfg.serial_baudrate = v

    @Property(int, notify=configLoaded)
    def serialBytesize(self):
        return self._cfg.serial_bytesize

    @serialBytesize.setter
    def serialBytesize(self, v):
        self._cfg.serial_bytesize = v

    @Property(str, notify=configLoaded)
    def serialParity(self):
        return self._cfg.serial_parity

    @serialParity.setter
    def serialParity(self, v):
        self._cfg.serial_parity = v

    @Property(int, notify=configLoaded)
    def serialStopbits(self):
        return self._cfg.serial_stopbits

    @serialStopbits.setter
    def serialStopbits(self, v):
        self._cfg.serial_stopbits = v

    @Property(str, notify=uiLocaleChanged)
    def uiLocale(self):
        loc = getattr(self._cfg, "ui_locale", None) or "vi"
        return loc if loc in ("en", "vi") else "vi"

    @uiLocale.setter
    def uiLocale(self, v: str):
        v = (v or "vi").lower()
        v = v if v in ("en", "vi") else "vi"
        if getattr(self._cfg, "ui_locale", "vi") == v:
            return
        self._cfg.ui_locale = v
        self.uiLocaleChanged.emit()

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def load_config(self):
        session = get_session()
        try:
            cfg = session.exec(select(AppConfig)).first()
            if cfg is None:
                cfg = AppConfig()
                session.add(cfg)
                session.commit()
                session.refresh(cfg)
            self._cfg = cfg
            self.configLoaded.emit()
            self.uiLocaleChanged.emit()
            logger.info("AppConfig loaded (id=%s)", cfg.id)
        except Exception as e:
            logger.error("load_config error: %s", e)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Could not load configuration: {0}").format(e),
            )
        finally:
            session.close()

    @Slot()
    def save_config(self):
        errors = self._validate()
        if errors:
            self.messageSent.emit(
                self.tr("Validation error"),
                "\n".join(errors),
            )
            return

        session = get_session()
        try:
            cfg = session.exec(select(AppConfig)).first()
            if cfg is None:
                cfg = AppConfig()
                session.add(cfg)

            cfg.station_code = self._cfg.station_code
            cfg.station_name = self._cfg.station_name
            cfg.ftp_address = self._cfg.ftp_address
            cfg.ftp_port = self._cfg.ftp_port
            cfg.ftp_username = self._cfg.ftp_username
            cfg.ftp_password = self._cfg.ftp_password
            cfg.ftp_remote_path = self._cfg.ftp_remote_path
            cfg.poll_interval = self._cfg.poll_interval
            cfg.serial_port = self._cfg.serial_port
            cfg.serial_baudrate = self._cfg.serial_baudrate
            cfg.serial_bytesize = self._cfg.serial_bytesize
            cfg.serial_parity = self._cfg.serial_parity
            cfg.serial_stopbits = self._cfg.serial_stopbits
            cfg.ui_locale = getattr(self._cfg, "ui_locale", "vi") or "vi"
            if cfg.ui_locale not in ("en", "vi"):
                cfg.ui_locale = "vi"

            session.commit()
            session.refresh(cfg)
            self._cfg = cfg
            self.configLoaded.emit()
            self.uiLocaleChanged.emit()
            self.configSaved.emit()
            self.messageSent.emit(self.tr("Success"), self.tr("Configuration saved."))
            logger.info("AppConfig saved (id=%s)", cfg.id)
        except Exception as e:
            session.rollback()
            logger.error("save_config error: %s", e)
            self.messageSent.emit(
                self.tr("Error"),
                self.tr("Failed to save configuration: {0}").format(e),
            )
        finally:
            session.close()

    @Slot(str, int, int, str, int)
    def save_serial_config(self, port: str, baudrate: int,
                           bytesize: int, parity: str, stopbits: int):
        """Lưu cấu hình serial (từ Tester page) không validate trạm/sFTP."""
        session = get_session()
        try:
            cfg = session.exec(select(AppConfig)).first()
            if cfg is None:
                cfg = AppConfig()
                session.add(cfg)

            cfg.serial_port = port
            cfg.serial_baudrate = baudrate
            cfg.serial_bytesize = bytesize
            cfg.serial_parity = parity
            cfg.serial_stopbits = stopbits
            session.commit()
            session.refresh(cfg)
            self._cfg = cfg
            self.configLoaded.emit()
            logger.info("Serial config saved: %s @ %d baud", port, baudrate)
        except Exception as e:
            session.rollback()
            logger.error("save_serial_config error: %s", e)
        finally:
            session.close()

    def _validate(self) -> list[str]:
        errors: list[str] = []
        if self._cfg.poll_interval < 1:
            errors.append(self.tr("Poll interval must be at least 1 second."))
        if self._cfg.ftp_port < 1 or self._cfg.ftp_port > 65535:
            errors.append(self.tr("FTP port must be between 1 and 65535."))
        return errors
