"""M5 — ReportController: quản lý FtpWorker trên QThread.

Start/stop sinh báo cáo TXT 5 phút/lần và gửi sFTP.
Expose trạng thái cho Main.qml sidebar indicator.
"""

import logging

from PySide6.QtCore import QObject, QThread, Property, Signal, Slot
from sqlmodel import select

from core.database import get_session
from models.report_log import ReportLog
from workers.ftp_worker import FtpWorker

logger = logging.getLogger("datalogger.report")


class ReportController(QObject):
    """Điều khiển FtpWorker — sinh báo cáo TXT & gửi sFTP."""

    runningChanged = Signal()
    lastStatusChanged = Signal()
    pendingCountChanged = Signal()
    messageSent = Signal(str, str)
    workerHeartbeat = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._is_running = False
        self._last_status = ""
        self._pending_count = 0
        self._worker: FtpWorker | None = None
        self._thread: QThread | None = None

    # ── Properties ─────────────────────────────────────────────────────────

    @Property(bool, notify=runningChanged)
    def isRunning(self):
        return self._is_running

    @Property(str, notify=lastStatusChanged)
    def lastStatus(self):
        return self._last_status

    @Property(int, notify=pendingCountChanged)
    def pendingCount(self):
        return self._pending_count

    # ── Slots ──────────────────────────────────────────────────────────────

    @Slot()
    def start_reporting(self):
        if self._is_running:
            return

        # Đọc interval từ cấu hình DB
        interval = 5
        try:
            from models.app_config import AppConfig
            session = get_session()
            config = session.exec(select(AppConfig)).first()
            if config and config.server_send_interval:
                interval = max(1, config.server_send_interval)
            session.close()
        except Exception as e:
            logger.warning("Could not read interval from DB, using default %d min: %s", interval, e)

        self._worker = FtpWorker(interval_minutes=interval)
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.worker_stopped.connect(self._on_worker_stopped)
        self._worker.ftp_status.connect(self._on_ftp_status)
        self._worker.heartbeat.connect(self.workerHeartbeat)

        self._thread.start()
        self._is_running = True
        self._set_status("Report: running")
        self.runningChanged.emit()
        self._refresh_pending()
        logger.info("ReportController started (interval=%d min).", interval)

    @Slot()
    def stop_reporting(self):
        if not self._is_running:
            return

        self._is_running = False

        if self._worker:
            self._worker.stop()

        # Nếu thread vẫn đang chạy (worker bị block trong FTP I/O),
        # đợi worker_stopped signal để dọn dẹp an toàn thay vì
        # destroy QThread ngay lập tức gây crash.
        if self._thread and self._thread.isRunning():
            self._thread.quit()
            if not self._thread.wait(3000):
                logger.warning(
                    "FtpWorker thread did not stop within 3s, forcing termination to prevent crash..."
                )
                self._thread.terminate()
                self._thread.wait()

        self._cleanup_thread()
        self._set_status("Report: stopped")
        self.runningChanged.emit()
        logger.info("ReportController stopped.")

    def _cleanup_thread(self):
        """Dọn dẹp thread + worker references an toàn."""
        self._worker = None
        self._thread = None

    @Slot()
    def refresh_pending(self):
        self._refresh_pending()

    # ── Internal ───────────────────────────────────────────────────────────

    def _on_ftp_status(self, msg: str) -> None:
        self._set_status(msg)
        self._refresh_pending()
        if msg.startswith("FAIL") or msg.startswith("ERROR"):
            logger.warning("FTP: %s", msg)
        else:
            logger.info("FTP: %s", msg)

    def _on_worker_stopped(self) -> None:
        if self._thread and self._thread.isRunning():
            self._thread.quit()
            self._thread.wait(3000)
        self._cleanup_thread()
        if self._is_running:
            self._is_running = False
            self._set_status("Report: worker exited")
            self.runningChanged.emit()

    def _refresh_pending(self) -> None:
        session = get_session()
        try:
            count = len(
                session.exec(
                    select(ReportLog).where(
                        ReportLog.status.in_(["pending", "failed"])
                    )
                ).all()
            )
            self._pending_count = count
            self.pendingCountChanged.emit()
        except Exception as e:
            logger.error("refresh_pending error: %s", e)
        finally:
            session.close()

    def _set_status(self, text: str) -> None:
        self._last_status = text
        self.lastStatusChanged.emit()
