"""M2 — SettingsController: load / save AppConfig (1 dòng) từ SQLite.

FTP password được encrypt bằng Fernet trước khi lưu DB,
và decrypt khi load lên QML.

Chuyển đổi hệ số cảm biến (scaling): QML gửi mode + số dạng chuỗi,
Python tạo JSON `coefficient` tương thích `core/formula.apply_formula`.
"""

from __future__ import annotations

import json
import logging
import math

from PySide6.QtCore import QObject, Property, Signal, Slot
from sqlmodel import select

from core.crypto import decrypt, encrypt
from core.database import get_session
from models.app_config import AppConfig

logger = logging.getLogger(__name__)


class SettingsController(QObject):
    configLoaded = Signal()
    configSaved = Signal()
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

    # ── General Properties ─────────────────────────────────────────────────

    @Property(str, notify=configLoaded)
    def timeFormat(self):
        return self._cfg.time_format

    @timeFormat.setter
    def timeFormat(self, v):
        self._cfg.time_format = v

    @Property(str, notify=configLoaded)
    def dateFormat(self):
        return self._cfg.date_format

    @dateFormat.setter
    def dateFormat(self, v):
        self._cfg.date_format = v

    @Property(str, notify=configLoaded)
    def timezone(self):
        return self._cfg.timezone

    @timezone.setter
    def timezone(self, v):
        self._cfg.timezone = v

    @Property(bool, notify=configLoaded)
    def autoSyncTime(self):
        return self._cfg.auto_sync_time

    @autoSyncTime.setter
    def autoSyncTime(self, v):
        self._cfg.auto_sync_time = v

    @Property(bool, notify=configLoaded)
    def buzzerEnable(self):
        return self._cfg.buzzer_enable

    @buzzerEnable.setter
    def buzzerEnable(self, v):
        self._cfg.buzzer_enable = v

    # ── Server / Transmission Properties ───────────────────────────────────

    @Property(bool, notify=configLoaded)
    def serverActive(self):
        return self._cfg.server_active

    @serverActive.setter
    def serverActive(self, v):
        self._cfg.server_active = v

    @Property(str, notify=configLoaded)
    def serverDeviceType(self):
        return self._cfg.server_device_type

    @serverDeviceType.setter
    def serverDeviceType(self, v):
        self._cfg.server_device_type = v

    @Property(str, notify=configLoaded)
    def serverName(self):
        return self._cfg.server_name

    @serverName.setter
    def serverName(self, v):
        self._cfg.server_name = v

    @Property(int, notify=configLoaded)
    def serverSendInterval(self):
        return self._cfg.server_send_interval

    @serverSendInterval.setter
    def serverSendInterval(self, v):
        self._cfg.server_send_interval = v

    @Property(str, notify=configLoaded)
    def serverStartTime(self):
        return self._cfg.server_start_time

    @serverStartTime.setter
    def serverStartTime(self, v):
        self._cfg.server_start_time = v

    @Property(str, notify=configLoaded)
    def serverBaseFolder(self):
        return self._cfg.server_base_folder

    @serverBaseFolder.setter
    def serverBaseFolder(self, v):
        self._cfg.server_base_folder = v

    @Property(str, notify=configLoaded)
    def serverTimeFolder(self):
        return self._cfg.server_time_folder

    @serverTimeFolder.setter
    def serverTimeFolder(self, v):
        self._cfg.server_time_folder = v

    @Property(str, notify=configLoaded)
    def ftpPrefix(self):
        return self._cfg.ftp_prefix

    @ftpPrefix.setter
    def ftpPrefix(self, v):
        self._cfg.ftp_prefix = v

    @Property(str, notify=configLoaded)
    def serverFileSuffix(self):
        return self._cfg.server_file_suffix

    @serverFileSuffix.setter
    def serverFileSuffix(self, v):
        self._cfg.server_file_suffix = v


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
            logger.info("AppConfig loaded (id=%s)", cfg.id)
        except Exception as e:
            logger.error("load_config error: %s", e)
            self.messageSent.emit(
                "Error",
                "Could not load configuration: {0}".format(e),
            )
        finally:
            session.close()

    @Slot()
    def save_config(self):
        errors = self._validate()
        if errors:
            self.messageSent.emit(
                "Validation error",
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
            cfg.time_format = self._cfg.time_format
            cfg.date_format = self._cfg.date_format
            cfg.timezone = self._cfg.timezone
            cfg.auto_sync_time = self._cfg.auto_sync_time
            cfg.buzzer_enable = self._cfg.buzzer_enable
            cfg.ftp_address = self._cfg.ftp_address
            cfg.ftp_port = self._cfg.ftp_port
            cfg.ftp_username = self._cfg.ftp_username
            cfg.ftp_password = self._cfg.ftp_password
            cfg.ftp_remote_path = self._cfg.ftp_remote_path
            cfg.ftp_prefix = self._cfg.ftp_prefix
            cfg.poll_interval = self._cfg.poll_interval
            cfg.serial_port = self._cfg.serial_port
            cfg.serial_baudrate = self._cfg.serial_baudrate
            cfg.serial_bytesize = self._cfg.serial_bytesize
            cfg.serial_parity = self._cfg.serial_parity
            cfg.serial_stopbits = self._cfg.serial_stopbits
            cfg.server_active = self._cfg.server_active
            cfg.server_device_type = self._cfg.server_device_type
            cfg.server_name = self._cfg.server_name
            cfg.server_send_interval = self._cfg.server_send_interval
            cfg.server_start_time = self._cfg.server_start_time
            cfg.server_base_folder = self._cfg.server_base_folder
            cfg.server_time_folder = self._cfg.server_time_folder
            cfg.server_file_suffix = self._cfg.server_file_suffix
            session.commit()
            session.refresh(cfg)
            self._cfg = cfg
            self.configLoaded.emit()
            self.configSaved.emit()
            self.messageSent.emit("Success", "Configuration saved.")
            logger.info("AppConfig saved (id=%s)", cfg.id)
        except Exception as e:
            session.rollback()
            logger.error("save_config error: %s", e)
            self.messageSent.emit(
                "Error",
                "Failed to save configuration: {0}".format(e),
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
            errors.append("Poll interval must be at least 1 second.")
        if self._cfg.ftp_port < 1 or self._cfg.ftp_port > 65535:
            errors.append("FTP port must be between 1 and 65535.")
        return errors

    # ── Sensor coefficient (scaling) helpers for QML ───────────────────────

    def _parse_float_token(self, label: str, s: str) -> tuple[float | None, str | None]:
        t = (s or "").strip().replace(",", ".")
        if not t:
            return None, "{0} is required.".format(label)
        try:
            v = float(t)
        except ValueError:
            return None, "{0}: invalid number.".format(label)
        if not math.isfinite(v):
            return None, "{0}: must be a finite number.".format(label)
        return v, None

    @Slot(str, result="QVariantMap")
    def coefficientUiState(self, coefficient_json: str) -> dict:
        """Parse DB `coefficient` JSON → trạng thái UI (mode + chuỗi hiển thị).

        mode: 0 = none, 1 = linear a,b, 2 = two-point (chỉ UI), 3 = JSON thủ công
        (đa thức / công thức lạ / JSON lỗi).
        """
        raw = (coefficient_json or "").strip() or "{}"
        blank = {
            "mode": 0,
            "linearA": "1",
            "linearB": "0",
            "rawMin": "4000",
            "rawMax": "20000",
            "scaleMin": "4",
            "scaleMax": "20",
            "legacyJson": "{}",
        }
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            d = dict(blank)
            d["mode"] = 3
            d["legacyJson"] = raw
            return d
        if not isinstance(obj, dict):
            d = dict(blank)
            d["mode"] = 3
            d["legacyJson"] = raw
            return d
        if not obj:
            d = dict(blank)
            d["legacyJson"] = "{}"
            return d
        if "coeffs" in obj:
            d = dict(blank)
            d["mode"] = 3
            d["legacyJson"] = raw
            return d
        if "a" in obj:
            try:
                a = float(obj.get("a", 1.0))
                b = float(obj.get("b", 0.0))
            except (TypeError, ValueError):
                d = dict(blank)
                d["mode"] = 3
                d["legacyJson"] = raw
                return d
            if not math.isfinite(a) or not math.isfinite(b):
                d = dict(blank)
                d["mode"] = 3
                d["legacyJson"] = raw
                return d
            return {
                "mode": 1,
                "linearA": str(a),
                "linearB": str(b),
                "rawMin": blank["rawMin"],
                "rawMax": blank["rawMax"],
                "scaleMin": blank["scaleMin"],
                "scaleMax": blank["scaleMax"],
                "legacyJson": "{}",
            }
        d = dict(blank)
        d["mode"] = 3
        d["legacyJson"] = raw
        return d

    @Slot(int, str, str, str, str, str, result=str)
    def buildCoefficientJson(
        self,
        mode: int,
        legacy_json: str,
        s0: str,
        s1: str,
        s2: str,
        s3: str,
    ) -> str:
        """Tạo chuỗi JSON coefficient từ chế độ scaling (gọi từ QML).

        Trả về chuỗi JSON hợp lệ; chuỗi rỗng nếu lỗi (đồng thời `messageSent`).
        """
        if mode == 0:
            return "{}"
        if mode == 1:
            a, err_a = self._parse_float_token("Gain (a)", s0)
            b, err_b = self._parse_float_token("Offset (b)", s1)
            if err_a:
                self.messageSent.emit("Validation error", err_a)
                return ""
            if err_b:
                self.messageSent.emit("Validation error", err_b)
                return ""
            return json.dumps({"a": a, "b": b}, separators=(",", ":"))
        if mode == 2:
            r0, e0 = self._parse_float_token("Raw Min", s0)
            r1, e1 = self._parse_float_token("Raw Max", s1)
            y0, e2 = self._parse_float_token("Scale Min", s2)
            y1, e3 = self._parse_float_token("Scale Max", s3)
            for msg in (e0, e1, e2, e3):
                if msg:
                    self.messageSent.emit("Validation error", msg)
                    return ""
            assert r0 is not None and r1 is not None and y0 is not None and y1 is not None
            denom = r1 - r0
            if denom == 0.0:
                self.messageSent.emit(
                    "Validation error",
                    "Raw Max must differ from Raw Min (division by zero).",
                )
                return ""
            a = (y1 - y0) / denom
            b = y0 - a * r0
            return json.dumps({"a": a, "b": b}, separators=(",", ":"))
        if mode == 3:
            t = (legacy_json or "").strip() or "{}"
            try:
                obj = json.loads(t)
            except json.JSONDecodeError as e:
                self.messageSent.emit(
                    "Validation error",
                    "Invalid JSON: {0}".format(e),
                )
                return ""
            if not isinstance(obj, dict):
                self.messageSent.emit(
                    "Validation error",
                    "Coefficient JSON must be an object {{ ... }}.",
                )
                return ""
            return json.dumps(obj, separators=(",", ":"))
        self.messageSent.emit(
            "Validation error",
            "Unknown scaling mode.",
        )
        return ""
