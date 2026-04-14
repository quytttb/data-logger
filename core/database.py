"""Data Logger — Core Database Engine.

Khởi tạo SQLite Engine với cấu hình PRAGMA tối ưu cho môi trường
công nghiệp đa luồng 24/7.
"""

from sqlalchemy import event
from sqlmodel import SQLModel, Session, create_engine

from core._paths import DATA_DIR

DATABASE_URL = f"sqlite:///{DATA_DIR / 'datalogger.db'}"

engine = create_engine(
    DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False},  # Cho phép đa luồng
)


@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    """Thiết lập PRAGMA cứng mỗi lần mở kết nối SQLite."""
    cursor = dbapi_connection.cursor()

    # WAL: Cho phép đọc/ghi song song (Worker INSERT + GUI SELECT)
    cursor.execute("PRAGMA journal_mode = WAL;")

    # NORMAL: Cân bằng giữa tốc độ và an toàn dữ liệu
    cursor.execute("PRAGMA synchronous = NORMAL;")

    # MEMORY: Dùng RAM cho temp tables, giảm ghi vật lý xuống SSD
    cursor.execute("PRAGMA temp_store = MEMORY;")

    # 8MB cache: Tăng hiệu suất truy vấn lịch sử
    cursor.execute("PRAGMA cache_size = -8000;")

    cursor.close()


def init_db() -> None:
    """Tạo toàn bộ bảng nếu chưa tồn tại."""
    from models import app_config, report_log, sensor, sensor_data  # noqa: F401

    SQLModel.metadata.create_all(engine)
    _migrate()


def _migrate() -> None:
    """Thêm cột mới cho bảng cũ (không dùng Alembic)."""
    from sqlalchemy import inspect as sa_inspect, text

    with engine.connect() as conn:
        inspector = sa_inspect(engine)
        cols = {c["name"] for c in inspector.get_columns("sensor")}
        if "poll_interval" not in cols:
            conn.execute(text(
                "ALTER TABLE sensor ADD COLUMN poll_interval INTEGER DEFAULT 3"
            ))
            conn.commit()

        if inspector.has_table("app_config"):
            acols = {c["name"] for c in inspector.get_columns("app_config")}
            # Thêm cột mới theo từng phiên bản model (DB cũ / file sqlite trong repo).
            app_config_adds: list[tuple[str, str]] = [
                ("ui_locale", "VARCHAR(8) DEFAULT 'vi'"),
                ("serial_port", "VARCHAR DEFAULT '/dev/ttyUSB0'"),
                ("serial_baudrate", "INTEGER DEFAULT 9600"),
                ("serial_bytesize", "INTEGER DEFAULT 8"),
                ("serial_parity", "VARCHAR DEFAULT 'N'"),
                ("serial_stopbits", "INTEGER DEFAULT 1"),
            ]
            for col_name, col_type in app_config_adds:
                if col_name not in acols:
                    conn.execute(
                        text(f"ALTER TABLE app_config ADD COLUMN {col_name} {col_type}")
                    )
                    conn.commit()
                    acols.add(col_name)


def get_session() -> Session:
    """Tạo Session mới cho mỗi tác vụ DB."""
    return Session(engine)
