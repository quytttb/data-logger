"""Add REST API columns to app_config (remote config v1).

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-05-15 12:00:00.000000

Cấu hình từ xa cho Central App (LAN nội bộ):
  - rest_api_enabled (bool)
  - rest_api_port (int, default 8080)
  - rest_api_bind (str, default 0.0.0.0)
  - rest_api_token (str, bearer token)
  - config_revision (int, optimistic concurrency)
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(sa.text(f"PRAGMA table_info({table})"))
    return column in [row[1] for row in result]


def upgrade() -> None:
    """Add REST API columns (idempotent — safe if upgraded twice)."""
    cols = {
        "rest_api_enabled": "ALTER TABLE app_config ADD COLUMN rest_api_enabled BOOLEAN NOT NULL DEFAULT 0",
        "rest_api_port": "ALTER TABLE app_config ADD COLUMN rest_api_port INTEGER NOT NULL DEFAULT 8080",
        "rest_api_bind": "ALTER TABLE app_config ADD COLUMN rest_api_bind VARCHAR NOT NULL DEFAULT '0.0.0.0'",
        "rest_api_token": "ALTER TABLE app_config ADD COLUMN rest_api_token VARCHAR NOT NULL DEFAULT ''",
        "config_revision": "ALTER TABLE app_config ADD COLUMN config_revision INTEGER NOT NULL DEFAULT 1",
    }
    for col, sql in cols.items():
        if not _column_exists("app_config", col):
            op.execute(sql)


def downgrade() -> None:
    """Remove the REST API columns (SQLite 3.35+ supports DROP COLUMN)."""
    for col in (
        "config_revision",
        "rest_api_token",
        "rest_api_bind",
        "rest_api_port",
        "rest_api_enabled",
    ):
        if _column_exists("app_config", col):
            op.execute(f"ALTER TABLE app_config DROP COLUMN {col}")
