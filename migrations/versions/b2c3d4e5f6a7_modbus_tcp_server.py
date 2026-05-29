"""Add Modbus TCP server settings to app_config.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-05-13 17:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(sa.text(f"PRAGMA table_info({table})"))
    return column in [row[1] for row in result]


def upgrade() -> None:
    """Add Modbus TCP server columns (idempotent — safe if upgraded twice)."""
    cols = {
        "modbus_tcp_enabled": "ALTER TABLE app_config ADD COLUMN modbus_tcp_enabled BOOLEAN NOT NULL DEFAULT 0",
        "modbus_tcp_port": "ALTER TABLE app_config ADD COLUMN modbus_tcp_port INTEGER NOT NULL DEFAULT 5020",
        "modbus_tcp_bind": "ALTER TABLE app_config ADD COLUMN modbus_tcp_bind VARCHAR NOT NULL DEFAULT '0.0.0.0'",
        "modbus_tcp_unit_id": "ALTER TABLE app_config ADD COLUMN modbus_tcp_unit_id INTEGER NOT NULL DEFAULT 1",
    }
    for col, sql in cols.items():
        if not _column_exists("app_config", col):
            op.execute(sql)


def downgrade() -> None:
    """Remove the Modbus TCP columns (SQLite 3.35+ supports DROP COLUMN)."""
    for col in (
        "modbus_tcp_unit_id",
        "modbus_tcp_bind",
        "modbus_tcp_port",
        "modbus_tcp_enabled",
    ):
        if _column_exists("app_config", col):
            op.execute(f"ALTER TABLE app_config DROP COLUMN {col}")
