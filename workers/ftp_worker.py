"""Worker FtpWorker — Lập lịch sinh file TXT và gửi sFTP.

Chạy trên QThread riêng biệt, sử dụng asyncssh để đẩy file
lên FTP Server Sở TNMT. Tự động retry các file pending/failed.
"""

import logging
from datetime import datetime, timedelta

from PySide6.QtCore import QObject, Signal

from sqlmodel import select

from core.crypto import decrypt
from core.database import get_session
from core.txt_generator import generate_report
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

    def __init__(self, interval_minutes: int = 5, parent: QObject | None = None):
        super().__init__(parent)
        self._interval = interval_minutes
        self._is_running = False

    def run(self) -> None:
        """Vòng lặp chính — sinh file và gửi FTP theo chu kỳ."""
        self._is_running = True
        logger.info("FtpWorker đã khởi động (chu kỳ %d phút).", self._interval)

        while self._is_running:
            try:
                self._generate_and_send()
                self._retry_pending()
            except Exception as e:
                logger.error("FtpWorker lỗi: %s", e, exc_info=True)
                self.ftp_status.emit(f"ERROR: {e}")

            # Chờ đến chu kỳ tiếp theo
            for _ in range(self._interval * 60):
                if not self._is_running:
                    break
                import time
                time.sleep(1)

        logger.info("FtpWorker đã dừng.")
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
                logger.warning("Chưa có cấu hình AppConfig trong DB.")
                return

            # Lấy danh sách cảm biến active, sắp xếp theo report_index
            sensors = session.exec(
                select(Sensor)
                .where(Sensor.active == True)  # noqa: E712
                .where(Sensor.report_index > 0)
                .order_by(Sensor.report_index)
            ).all()

            if not sensors:
                logger.warning("Không có cảm biến nào được cấu hình report_index.")
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
                logger.info("Không có dữ liệu mới trong %d phút qua.", self._interval)
                return

            # Chuyển sang dict cho TxtGenerator
            records = [
                {
                    "sensor_id": r.sensor_id,
                    "value": r.value,
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
            )

            # Tạo ReportLog
            filename = filepath.split("/")[-1]
            report_log = ReportLog(filename=filename, status="pending")
            session.add(report_log)
            session.commit()

            # Gửi sFTP
            success = self._upload_sftp(
                filepath=filepath,
                host=config.ftp_address,
                port=config.ftp_port,
                username=config.ftp_username,
                password=decrypt(config.ftp_password) if config.ftp_password else "",
                remote_path=config.ftp_remote_path,
            )

            if success:
                report_log.status = "sent"
                report_log.sent_at = datetime.now()
                session.commit()
                self.ftp_status.emit(f"OK: {filename}")
                logger.info("Đã gửi thành công: %s", filename)
            else:
                report_log.status = "failed"
                report_log.retry_count += 1
                report_log.error_message = "Upload failed"
                session.commit()
                self.ftp_status.emit(f"FAIL: {filename}")

        except Exception as e:
            logger.error("Lỗi generate_and_send: %s", e, exc_info=True)
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
                .where(ReportLog.retry_count < MAX_RETRY)
            ).all()

            for log in pending_logs:
                from core.txt_generator import REPORT_DIR
                filepath = str(REPORT_DIR / log.filename)

                success = self._upload_sftp(
                    filepath=filepath,
                    host=config.ftp_address,
                    port=config.ftp_port,
                    username=config.ftp_username,
                    password=decrypt(config.ftp_password) if config.ftp_password else "",
                    remote_path=config.ftp_remote_path,
                )

                if success:
                    log.status = "sent"
                    log.sent_at = datetime.now()
                    logger.info("Retry thành công: %s", log.filename)
                else:
                    log.retry_count += 1
                    log.error_message = "Retry failed"
                    logger.warning(
                        "Retry thất bại: %s (lần %d/%d)",
                        log.filename, log.retry_count, MAX_RETRY,
                    )

            session.commit()
        except Exception as e:
            logger.error("Lỗi retry_pending: %s", e, exc_info=True)
        finally:
            session.close()

    @staticmethod
    def _upload_sftp(
        filepath: str,
        host: str,
        port: int,
        username: str,
        password: str,
        remote_path: str,
    ) -> bool:
        """Upload file qua sFTP sử dụng asyncssh.

        Returns:
            True nếu upload thành công, False nếu thất bại.
        """
        import asyncio
        import asyncssh
        from pathlib import Path

        known_hosts_path = Path.home() / ".ssh" / "known_hosts"
        known_hosts: str | None = str(known_hosts_path) if known_hosts_path.is_file() else None
        if known_hosts is None:
            logger.warning(
                "sFTP: không tìm thấy ~/.ssh/known_hosts — không xác thực host key "
                "(chấp nhận mọi server). Nên tạo known_hosts trên thiết bị triển khai."
            )

        async def _do_upload():
            try:
                async with asyncssh.connect(
                    host=host,
                    port=port,
                    username=username,
                    password=password,
                    known_hosts=known_hosts,
                    connect_timeout=10,
                ) as conn:
                    async with conn.start_sftp_client() as sftp:
                        remote_file = f"{remote_path.rstrip('/')}/{Path(filepath).name}"
                        await sftp.put(filepath, remote_file)
                        logger.info("Upload sFTP thành công: %s → %s", filepath, remote_file)
                        return True
            except Exception as e:
                logger.error("Upload sFTP thất bại: %s — %s", filepath, e)
                return False

        try:
            return asyncio.run(_do_upload())
        except Exception as e:
            logger.error("Lỗi event loop sFTP: %s", e)
            return False
