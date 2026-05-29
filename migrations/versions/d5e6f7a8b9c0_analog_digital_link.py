"""Add analog_digital_link table; migrate parent_id children to links.

Revision ID: d5e6f7a8b9c0
Revises: c3d4e5f6a7b8
Create Date: 2026-05-28 00:00:00.000000

Changes:
  1. Create analog_digital_link table.
  2. For each sensor with parent_id IS NOT NULL (child DI/DO):
       - Insert a link row (analog_sensor_id=parent_id, digital_sensor_id=sensor.id).
       - Set parent_id = NULL (promote to top-level).
  3. Drop is_system_wide column.
  4. Drop parent_id column.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d5e6f7a8b9c0"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(name: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(
        sa.text("SELECT name FROM sqlite_master WHERE type='table' AND name=:n"), {"n": name}
    )
    return result.fetchone() is not None


def _column_exists(table: str, column: str) -> bool:
    conn = op.get_bind()
    result = conn.execute(sa.text(f"PRAGMA table_info({table})"))
    return column in [row[1] for row in result]


def upgrade() -> None:
    if not _table_exists("analog_digital_link"):
        op.create_table(
            "analog_digital_link",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("analog_sensor_id", sa.Integer(), sa.ForeignKey("sensor.id"), nullable=False),
            sa.Column(
                "digital_sensor_id", sa.Integer(), sa.ForeignKey("sensor.id"), nullable=False
            ),
            sa.Column("di_type", sa.String(), nullable=True),
            sa.Column("trigger_on_max", sa.Boolean(), nullable=False, server_default=sa.text("1")),
            sa.Column("trigger_on_min", sa.Boolean(), nullable=False, server_default=sa.text("1")),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("analog_sensor_id", "digital_sensor_id"),
        )

    # Migrate existing child sensors (parent_id IS NOT NULL) → link rows
    if _column_exists("sensor", "parent_id"):
        conn = op.get_bind()
        rows = conn.execute(
            sa.text(
                "SELECT id, parent_id, sensor_type, di_type, trigger_on_max, trigger_on_min "
                "FROM sensor WHERE parent_id IS NOT NULL"
            )
        ).fetchall()

        for row in rows:
            sensor_id, parent_id, sensor_type, di_type, trig_max, trig_min = row
            # Only migrate valid DI/DO children
            if sensor_type not in ("DI", "DO"):
                continue
            # Check if link already exists (idempotent)
            existing = conn.execute(
                sa.text(
                    "SELECT id FROM analog_digital_link WHERE analog_sensor_id=:a AND digital_sensor_id=:d"
                ),
                {"a": parent_id, "d": sensor_id},
            ).fetchone()
            if not existing:
                conn.execute(
                    sa.text(
                        "INSERT INTO analog_digital_link "
                        "(analog_sensor_id, digital_sensor_id, di_type, trigger_on_max, trigger_on_min, created_at) "
                        "VALUES (:a, :d, :dt, :tm, :tmin, datetime('now'))"
                    ),
                    {
                        "a": parent_id,
                        "d": sensor_id,
                        "dt": di_type,
                        "tm": bool(trig_max),
                        "tmin": bool(trig_min),
                    },
                )

        # Promote all children to top-level
        conn.execute(sa.text("UPDATE sensor SET parent_id = NULL WHERE parent_id IS NOT NULL"))
        conn.commit()

    # Drop is_system_wide
    if _column_exists("sensor", "is_system_wide"):
        op.execute(sa.text("ALTER TABLE sensor DROP COLUMN is_system_wide"))

    # Drop parent_id
    if _column_exists("sensor", "parent_id"):
        op.execute(sa.text("ALTER TABLE sensor DROP COLUMN parent_id"))


def downgrade() -> None:
    if not _column_exists("sensor", "parent_id"):
        op.execute(sa.text("ALTER TABLE sensor ADD COLUMN parent_id INTEGER DEFAULT NULL"))
    if not _column_exists("sensor", "is_system_wide"):
        op.execute(
            sa.text("ALTER TABLE sensor ADD COLUMN is_system_wide BOOLEAN NOT NULL DEFAULT 0")
        )

    if _table_exists("analog_digital_link"):
        conn = op.get_bind()
        rows = conn.execute(
            sa.text(
                "SELECT analog_sensor_id, digital_sensor_id, di_type, trigger_on_max, trigger_on_min "
                "FROM analog_digital_link"
            )
        ).fetchall()
        for row in rows:
            analog_id, digital_id, di_type, trig_max, trig_min = row
            conn.execute(
                sa.text("UPDATE sensor SET parent_id=:p, is_system_wide=0 WHERE id=:d"),
                {"p": analog_id, "d": digital_id},
            )
        conn.commit()
        op.drop_table("analog_digital_link")
