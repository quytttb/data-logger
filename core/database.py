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
    cursor.execute("PRAGMA journal_size_limit = 1000000;")
    cursor.execute("PRAGMA mmap_size = 30000000;")

    # MEMORY: Dùng RAM cho temp tables, giảm ghi vật lý xuống SSD
    cursor.execute("PRAGMA temp_store = MEMORY;")

    # 20MB cache: Tăng hiệu suất truy vấn lịch sử
    cursor.execute("PRAGMA cache_size = -20000;")

    cursor.close()


def init_db() -> None:
    """Tạo toàn bộ bảng nếu chưa tồn tại."""
    from models import analog_digital_link, app_config, report_log, sensor, sensor_data  # noqa: F401

    SQLModel.metadata.create_all(engine)
    _migrate()


def _add_columns(
    conn,
    table: str,
    adds: list[tuple[str, str]],
    existing: set[str],
) -> None:
    """ALTER TABLE ADD COLUMN cho từng cột chưa có (idempotent)."""
    from sqlalchemy import text

    for col_name, col_type in adds:
        if col_name not in existing:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col_name} {col_type}"))
            conn.commit()
            existing.add(col_name)


def _migrate_digital_io(conn, inspector) -> None:
    """Gộp bảng digital_io cũ vào sensor (migration a1b2c3d4e5f6)."""
    from sqlalchemy import text

    if "digital_io" not in inspector.get_table_names():
        return
    if "sensor_type" not in {c["name"] for c in inspector.get_columns("sensor")}:
        return

    sensor_cols = {c["name"] for c in inspector.get_columns("sensor")}
    if "parent_id" in sensor_cols:
        conn.execute(text("""
            INSERT INTO sensor (
                sensor_type, name, unit, slave_id, register_address,
                register_type, data_type, data_format, coefficient,
                poll_interval, report_index,
                parent_id, di_type,
                trigger_on_max, trigger_on_min,
                active, created_at
            )
            SELECT
                io_type, label, '',
                slave_id, address,
                CASE WHEN io_type = 'DI' THEN 'discrete_input' ELSE 'coil' END,
                'int16', 'AB', '{}', 3, 0,
                sensor_id, di_type,
                trigger_on_max, trigger_on_min,
                active, created_at
            FROM digital_io
        """))
    conn.execute(text("DROP TABLE digital_io"))
    conn.commit()


def _migrate_analog_digital_link(conn, inspector) -> None:
    """Migrate child DI/DO sensors (parent_id IS NOT NULL) → analog_digital_link rows (d5e6f7a8b9c0)."""
    from sqlalchemy import text

    if "analog_digital_link" not in inspector.get_table_names():
        return

    sensor_cols = {c["name"] for c in inspector.get_columns("sensor")}
    if "parent_id" not in sensor_cols:
        return

    rows = conn.execute(text(
        "SELECT id, parent_id, sensor_type, di_type, trigger_on_max, trigger_on_min "
        "FROM sensor WHERE parent_id IS NOT NULL"
    )).fetchall()

    for row in rows:
        sensor_id, parent_id, sensor_type, di_type, trig_max, trig_min = row
        if sensor_type not in ("DI", "DO"):
            continue
        existing = conn.execute(text(
            "SELECT id FROM analog_digital_link WHERE analog_sensor_id=:a AND digital_sensor_id=:d"
        ), {"a": parent_id, "d": sensor_id}).fetchone()
        if not existing:
            conn.execute(text(
                "INSERT INTO analog_digital_link "
                "(analog_sensor_id, digital_sensor_id, di_type, trigger_on_max, trigger_on_min, created_at) "
                "VALUES (:a, :d, :dt, :tm, :tmin, datetime('now'))"
            ), {"a": parent_id, "d": sensor_id, "dt": di_type,
                "tm": bool(trig_max), "tmin": bool(trig_min)})

    conn.execute(text("UPDATE sensor SET parent_id = NULL WHERE parent_id IS NOT NULL"))
    conn.commit()


def _migrate() -> None:
    """Thêm cột mới cho bảng cũ (không dùng Alembic).

    Bổ sung các cột tương đương Alembic revisions a1/b2/c3 để DB dev/cũ
    trên Pi hoạt động sau khi nâng cấp .deb mà không cần sửa tay.
    """
    from sqlalchemy import inspect as sa_inspect, text

    with engine.connect() as conn:
        inspector = sa_inspect(engine)

        if inspector.has_table("sensor"):
            scols = {c["name"] for c in inspector.get_columns("sensor")}
            _add_columns(conn, "sensor", [
                ("poll_interval", "INTEGER DEFAULT 3"),
                ("min_threshold", "REAL DEFAULT NULL"),
                ("max_threshold", "REAL DEFAULT NULL"),
                ("sensor_type", "VARCHAR NOT NULL DEFAULT 'ANALOG'"),
                ("di_type", "VARCHAR DEFAULT NULL"),
                # Legacy columns for _migrate_analog_digital_link on old DBs
                ("parent_id", "INTEGER DEFAULT NULL"),
                ("is_system_wide", "BOOLEAN NOT NULL DEFAULT 0"),
            ], scols)
            if "sensor_type" in scols:
                conn.execute(text(
                    "UPDATE sensor SET sensor_type = 'ANALOG' "
                    "WHERE sensor_type IS NULL OR sensor_type = ''"
                ))
                conn.commit()
            _migrate_digital_io(conn, inspector)
            _migrate_analog_digital_link(conn, inspector)

        if inspector.has_table("app_config"):
            acols = {c["name"] for c in inspector.get_columns("app_config")}
            _add_columns(conn, "app_config", [
                ("ui_locale", "VARCHAR(8) DEFAULT 'vi'"),
                ("serial_port", "VARCHAR DEFAULT '/dev/ttyUSB0'"),
                ("serial_baudrate", "INTEGER DEFAULT 9600"),
                ("serial_bytesize", "INTEGER DEFAULT 8"),
                ("serial_parity", "VARCHAR DEFAULT 'N'"),
                ("serial_stopbits", "INTEGER DEFAULT 1"),
                ("time_format", "VARCHAR DEFAULT 'HH:mm:ss'"),
                ("date_format", "VARCHAR DEFAULT 'dd/MM/yyyy'"),
                ("timezone", "VARCHAR DEFAULT 'UTC+7'"),
                ("auto_sync_time", "BOOLEAN DEFAULT 0"),
                ("buzzer_enable", "BOOLEAN DEFAULT 0"),
                ("ftp_prefix", "VARCHAR DEFAULT ''"),
                ("server_active", "BOOLEAN DEFAULT 0"),
                ("server_device_type", "VARCHAR DEFAULT 'Standard'"),
                ("server_name", "VARCHAR DEFAULT ''"),
                ("server_send_interval", "INTEGER DEFAULT 5"),
                ("server_start_time", "VARCHAR DEFAULT '00:00'"),
                ("server_base_folder", "VARCHAR DEFAULT ''"),
                ("server_time_folder", "VARCHAR DEFAULT 'yyyy/MM/dd'"),
                ("server_file_suffix", "VARCHAR DEFAULT 'yyyyMMddHHmmss'"),
                ("ftp_protocol", "VARCHAR DEFAULT 'sftp'"),
                # Modbus TCP server (b2c3d4e5f6a7)
                ("modbus_tcp_enabled", "BOOLEAN NOT NULL DEFAULT 0"),
                ("modbus_tcp_port", "INTEGER NOT NULL DEFAULT 5020"),
                ("modbus_tcp_bind", "VARCHAR NOT NULL DEFAULT '0.0.0.0'"),
                ("modbus_tcp_unit_id", "INTEGER NOT NULL DEFAULT 1"),
                # REST API / remote config (c3d4e5f6a7b8)
                ("rest_api_enabled", "BOOLEAN NOT NULL DEFAULT 0"),
                ("rest_api_port", "INTEGER NOT NULL DEFAULT 8080"),
                ("rest_api_bind", "VARCHAR NOT NULL DEFAULT '0.0.0.0'"),
                ("rest_api_token", "VARCHAR NOT NULL DEFAULT ''"),
                ("config_revision", "INTEGER NOT NULL DEFAULT 1"),
            ], acols)

            if "sensor_data" in inspector.get_table_names():
                sdcols = {c["name"] for c in inspector.get_columns("sensor_data")}
                _add_columns(conn, "sensor_data", [
                    ("status", "VARCHAR DEFAULT NULL"),
                ], sdcols)


def get_session() -> Session:
    """Tạo Session mới cho mỗi tác vụ DB."""
    return Session(engine)
