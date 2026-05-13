"""Worker FtpWorker — Lập lịch sinh file TXT và gửi FTP.

Chạy trên QThread riêng biệt, sử dụng ftplib để đẩy file
lên FTP Server. Tự động retry các file pending/failed.
"""

import logging
import time
from datetime import datetime, timedelta

from PySide6.QtCore import QObject, Signal

from sqlmodel import select

from core.crypto import decrypt
from core.database import get_session
from core.txt_generator import cleanup_old_report_files, generate_report
from models.app_config import AppConfig
from models.report_log import ReportLog
from models.sensor import Sensor
from models.sensor_data import SensorData

logger = logging.getLogger("datalogger.ftp")

# Số lần retry tối đa cho mỗi file
MAX_RETRY = 5


class FtpWorker(QObject):
    """Worker sinh file TXT và gửi sFTP định kỳ.

    Signals:
        ftp_status(str): Phát trạng thái mỗi lần gửi (OK/FAIL + filename).
        worker_stopped(): Phát khi Worker đã dừng hoàn toàn.
    """

    ftp_status = Signal(str)
    worker_stopped = Signal()
    heartbeat = Signal(str)

    def __init__(self, interval_minutes: int = 5, parent: QObject | None = None):
        super().__init__(parent)
        self._interval = interval_minutes
        self._is_running = False

    def run(self) -> None:
        """Vòng lặp chính — sinh file và gửi FTP theo chu kỳ."""
        self._is_running = True
        logger.info("FtpWorker started (interval: %d min).", self._interval)

        while self._is_running:
            self.heartbeat.emit("FtpWorker")
            
            try:
                cleanup_old_report_files()
                self._generate_and_send()
                self._retry_pending()
            except Exception as e:
                logger.error("FtpWorker error: %s", e, exc_info=True)
                self.ftp_status.emit(f"ERROR: {e}")

            # Chờ đến chu kỳ tiếp theo
            last_time = time.time()
            for _ in range(self._interval * 60):
                if not self._is_running:
                    break
                time.sleep(1)
                if time.time() - last_time >= 5.0:
                    self.heartbeat.emit("FtpWorker")
                    last_time = time.time()

        logger.info("FtpWorker stopped.")
        self.worker_stopped.emit()

    def stop(self) -> None:
        """Yêu cầu dừng Worker."""
        self._is_running = False

    def _generate_and_send(self) -> None:
        """Sinh file TXT từ dữ liệu gần nhất và gửi sFTP."""
        session = get_session()

        try:
            # Lấy cấu hình trạm
            config = session.exec(select(AppConfig)).first()
            if not config:
                logger.warning("AppConfig not found in database.")
                return

            # Lấy danh sách cảm biến active, sắp xếp theo report_index
            sensors = session.exec(
                select(Sensor)
                .where(Sensor.active == True)  # noqa: E712
                .where(Sensor.report_index > 0)
                .order_by(Sensor.report_index)
            ).all()

            if not sensors:
                logger.warning("No sensors configured with report_index.")
                return

            # Truy vấn dữ liệu trong khoảng interval phút gần nhất
            now = datetime.now()
            time_from = now - timedelta(minutes=self._interval)

            sensor_ids = [s.id for s in sensors]
            records_raw = session.exec(
                select(SensorData)
                .where(SensorData.sensor_id.in_(sensor_ids))
                .where(SensorData.recorded_at >= time_from)
                .where(SensorData.recorded_at <= now)
                .order_by(SensorData.recorded_at)
            ).all()

            if not records_raw:
                logger.debug("No new data in the last %d minutes.", self._interval)
                return

            # Chuyển sang dict cho TxtGenerator
            records = [
                {
                    "sensor_id": r.sensor_id,
                    "value": r.value,
                    "status": getattr(r, "status", None),
                    "recorded_at": r.recorded_at,
                }
                for r in records_raw
            ]
            sensor_order = [
                {"id": s.id, "name": s.name, "unit": s.unit, "report_index": s.report_index}
                for s in sensors
            ]

            # Sinh file TXT
            filepath = generate_report(
                records=records,
                sensor_order=sensor_order,
                station_code=config.station_code,
                report_time=now,
                prefix=config.ftp_prefix or "",
                suffix_format=config.server_file_suffix or "yyyyMMddHHmmss",
            )

            # Tạo ReportLog
            filename = filepath.split("/")[-1]
            report_log = ReportLog(filename=filename, status="pending")
            session.add(report_log)
            session.commit()

            # Gửi file qua FTP
            success = self._upload_ftp(
                filepath=filepath,
                host=config.ftp_address,
                port=config.ftp_port,
                username=config.ftp_username,
                password=decrypt(config.ftp_password) if config.ftp_password else "",
                remote_path=self._build_remote_path(config),
            )

            if success:
                report_log.status = "sent"
                report_log.sent_at = datetime.now()
                session.commit()
                self.ftp_status.emit(f"OK: {filename}")
                logger.info("Successfully sent: %s", filename)
            else:
                report_log.status = "failed"
                report_log.retry_count += 1
                report_log.error_message = "Upload failed"
                session.commit()
                self.ftp_status.emit(f"FAIL: {filename}")

        except Exception as e:
            logger.error("Error in generate_and_send: %s", e, exc_info=True)
            self.ftp_status.emit(f"ERROR: {e}")
        finally:
            session.close()

    def _retry_pending(self) -> None:
        """Thử gửi lại các file pending/failed (retry_count < MAX_RETRY)."""
        session = get_session()

        try:
            config = session.exec(select(AppConfig)).first()
            if not config:
                return

            pending_logs = session.exec(
                select(ReportLog)
                .where(ReportLog.status.in_(["pending", "failed"]))
                .order_by(ReportLog.id)
            ).all()

            for log in pending_logs:
                if not self._is_running:
                    break  # Dừng ngay khi worker bị yêu cầu stop

                from core.txt_generator import REPORT_DIR
                filepath = str(REPORT_DIR / log.filename)

                # Bỏ qua file không còn tồn tại trên đĩa
                import os
                if not os.path.isfile(filepath):
                    log.status = "expired"
                    log.error_message = "File not found on disk"
                    session.commit()
                    logger.warning("File not found, marked expired: %s", log.filename)
                    continue

                success = self._upload_ftp(
                    filepath=filepath,
                    host=config.ftp_address,
                    port=config.ftp_port,
                    username=config.ftp_username,
                    password=decrypt(config.ftp_password) if config.ftp_password else "",
                    remote_path=self._build_remote_path(config),
                )

                if success:
                    log.status = "sent"
                    log.sent_at = datetime.now()
                    logger.info("Retry successful: %s", log.filename)
                    self.ftp_status.emit(f"OK: {log.filename} (retry)")
                    session.commit()
                    self.heartbeat.emit("FtpWorker")
                    time.sleep(2)  # Tránh gửi quá dồn dập bị server block
                else:
                    log.retry_count += 1
                    log.error_message = "Retry failed"
                    logger.warning(
                        "Retry failed: %s. Pausing backfill.",
                        log.filename
                    )
                    self.ftp_status.emit(f"FAIL: {log.filename} (retry)")
                    session.commit()
                    break  # Break out of loop immediately to prevent blocking

        except Exception as e:
            logger.error("Error in retry_pending: %s", e, exc_info=True)
        finally:
            session.close()

    @staticmethod
    def _build_remote_path(config: "AppConfig") -> str:
        """Xây dựng remote path động từ base_folder / time_folder.

        Khớp logic preview trên giao diện SettingsServerTab.qml.
        Format: /{base_folder}/{time_folder}/
        """
        now = datetime.now()
        base = (config.server_base_folder or "").strip()
        time_fmt = (config.server_time_folder or "").strip()

        # Chuyển pattern QML (yyyy/MM/dd) sang strftime (%Y/%m/%d)
        time_part = time_fmt.replace("yyyy", "%Y").replace("MM", "%m").replace("dd", "%d")
        time_part = now.strftime(time_part) if time_part else ""

        parts = [p for p in [base, time_part] if p]
        return "/".join(parts) if parts else "/"

    @staticmethod
    def _upload_ftp(
        filepath: str,
        host: str,
        port: int,
        username: str,
        password: str,
        remote_path: str,
    ) -> bool:
        """Upload file qua FTP sử dụng ftplib.

        Returns:
            True nếu upload thành công, False nếu thất bại.
        """
        import ftplib
        from pathlib import Path

        try:
            ftp = ftplib.FTP()
            ftp.connect(host=host, port=port, timeout=60)
            ftp.login(user=username, passwd=password)
            ftp.set_pasv(True)  # Passive mode — cần cho hầu hết FTP server
            logger.debug("FTP login successful: %s@%s:%d", username, host, port)

            # Tạo thư mục remote nếu chưa tồn tại (đệ quy)
            dirs = remote_path.strip("/").split("/")
            current = ""
            for d in dirs:
                if not d:
                    continue
                current += "/" + d
                try:
                    ftp.mkd(current)
                except ftplib.error_perm:
                    pass  # Thư mục đã tồn tại

            remote_file = f"{remote_path.rstrip('/')}/{Path(filepath).name}"
            with open(filepath, "rb") as f:
                ftp.storbinary(f"STOR {remote_file}", f)

            ftp.quit()
            logger.debug("FTP upload successful: %s → %s", filepath, remote_file)
            return True

        except Exception as e:
            logger.error("FTP upload failed: %s — %s", filepath, e)
            return False
