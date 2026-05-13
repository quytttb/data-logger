"""Worker DatabaseWorker — Gom batch & ghi dữ liệu vào SQLite.

Nhận dữ liệu từ hàng đợi (Queue), gom thành batch rồi INSERT
vào bảng sensor_data để giảm số lần thao tác ổ đĩa SSD.
"""

import logging
import time
from datetime import datetime
from queue import Empty, Queue

from PySide6.QtCore import QObject, Signal

from core.database import get_session
from models.sensor_data import SensorData

logger = logging.getLogger("datalogger.database")

# Ngưỡng batch — gom đủ N bản ghi mới INSERT 1 lần
BATCH_SIZE = 50
# Timeout — nếu chưa đủ batch nhưng đợi quá lâu thì cũng flush
FLUSH_TIMEOUT = 5.0  # giây


class DatabaseWorker(QObject):
    """Worker ghi dữ liệu cảm biến vào SQLite theo batch.

    Signals:
        db_error(str): Phát khi gặp lỗi ghi DB.
        records_saved(int): Phát khi ghi batch thành công (số bản ghi).
    """

    db_error = Signal(str)
    records_saved = Signal(int)
    worker_stopped = Signal()
    heartbeat = Signal(str)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._queue: Queue[dict] = Queue()
        self._is_running = False

    def enqueue(self, data: dict) -> None:
        """Thêm 1 bản ghi vào hàng đợi chờ ghi.

        Args:
            data: Dict chứa sensor_id, raw_value, value, recorded_at.
        """
        self._queue.put(data)

    def run(self) -> None:
        """Vòng lặp chính — liên tục lấy dữ liệu từ Queue và ghi batch."""
        self._is_running = True
        batch: list[SensorData] = []

        logger.info("DatabaseWorker started.")

        try:
            last_heartbeat = time.monotonic()
            while self._is_running:
                now = time.monotonic()
                if now - last_heartbeat >= 5.0:
                    self.heartbeat.emit("DatabaseWorker")
                    last_heartbeat = now

                try:
                    data = self._queue.get(timeout=FLUSH_TIMEOUT)

                    record = SensorData(
                        sensor_id=data["sensor_id"],
                        raw_value=data.get("raw_value"),
                        value=data.get("value"),
                        status=data.get("status"),
                        recorded_at=datetime.fromisoformat(data["recorded_at"]),
                    )
                    batch.append(record)

                    if len(batch) >= BATCH_SIZE:
                        self._batch_insert(batch)
                        batch.clear()

                except Empty:
                    if batch:
                        self._batch_insert(batch)
                        batch.clear()

                except Exception as e:
                    error_msg = f"DatabaseWorker error: {e}"
                    logger.error(error_msg, exc_info=True)
                    self.db_error.emit(error_msg)

            if batch:
                self._batch_insert(batch)
                batch.clear()

            logger.info("DatabaseWorker stopped.")
        except Exception as e:
            logger.critical("DatabaseWorker crashed: %s", e, exc_info=True)
        finally:
            self._is_running = False
            self.worker_stopped.emit()

    def stop(self) -> None:
        """Yêu cầu dừng vòng lặp."""
        self._is_running = False

    def upgrade_database(self) -> None:
        """Chạy alembic upgrade head để update DB schema bằng Alembic API."""
        from alembic import command
        from alembic.config import Config
        from core._paths import ROOT_DIR
        try:
            logger.info("Running Alembic migration (upgrade head)...")
            alembic_cfg = Config(f"{ROOT_DIR}/alembic.ini")
            alembic_cfg.set_main_option("script_location", f"{ROOT_DIR}/migrations")
            command.upgrade(alembic_cfg, "head")
            logger.info("Alembic migration completed.")
        except Exception as e:
            logger.error(f"Migration error: {e}")

    def _batch_insert(self, batch: list[SensorData]) -> None:
        """Ghi batch bản ghi vào DB trong 1 transaction."""
        import time
        start_t = time.perf_counter()
        session = None
        try:
            session = get_session()
            session.add_all(batch)
            session.commit()
            session.close()
            session = None

            count = len(batch)
            duration = (time.perf_counter() - start_t) * 1000
            self.records_saved.emit(count)
            logger.debug(f"Batch insert {count} records in {duration:.2f}ms")

        except Exception as e:
            error_msg = f"Batch INSERT error: {e}"
            logger.error(error_msg, exc_info=True)
            self.db_error.emit(error_msg)
            if session is not None:
                try:
                    session.rollback()
                except Exception:
                    pass
                try:
                    session.close()
                except Exception:
                    pass
