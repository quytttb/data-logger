"""Worker DatabaseWorker — Gom batch & ghi dữ liệu vào SQLite.

Nhận dữ liệu từ hàng đợi (Queue), gom thành batch rồi INSERT
vào bảng sensor_data để giảm số lần thao tác ổ đĩa SSD.
"""

import logging
from datetime import datetime
from queue import Empty, Queue

from PySide6.QtCore import QObject, Signal

from core.database import get_session
from models.sensor_data import SensorData

logger = logging.getLogger("datalogger.database")

# Ngưỡng batch — gom đủ N bản ghi mới INSERT 1 lần
BATCH_SIZE = 10
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

        logger.info("DatabaseWorker đã khởi động.")

        try:
            while self._is_running:
                try:
                    data = self._queue.get(timeout=FLUSH_TIMEOUT)

                    record = SensorData(
                        sensor_id=data["sensor_id"],
                        raw_value=data.get("raw_value"),
                        value=data.get("value"),
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
                    error_msg = f"DatabaseWorker lỗi: {e}"
                    logger.error(error_msg, exc_info=True)
                    self.db_error.emit(error_msg)

            if batch:
                self._batch_insert(batch)
                batch.clear()

            logger.info("DatabaseWorker đã dừng.")
        except Exception as e:
            logger.critical("DatabaseWorker crashed: %s", e, exc_info=True)
        finally:
            self._is_running = False
            self.worker_stopped.emit()

    def stop(self) -> None:
        """Yêu cầu dừng vòng lặp."""
        self._is_running = False

    def _batch_insert(self, batch: list[SensorData]) -> None:
        """Ghi batch bản ghi vào DB trong 1 transaction."""
        try:
            session = get_session()
            session.add_all(batch)
            session.commit()
            session.close()

            count = len(batch)
            self.records_saved.emit(count)
            logger.info("Đã ghi %d bản ghi vào sensor_data.", count)

        except Exception as e:
            error_msg = f"Lỗi batch INSERT: {e}"
            logger.error(error_msg, exc_info=True)
            self.db_error.emit(error_msg)
            # Rollback nếu có lỗi
            try:
                session.rollback()
                session.close()
            except Exception:
                pass
