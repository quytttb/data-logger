"""Unify sensor model — merge digital_io into sensor table.

Revision ID: a1b2c3d4e5f6
Revises: 6277b5544943
Create Date: 2026-05-12 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '6277b5544943'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    """Check if a column exists in a SQLite table."""
    conn = op.get_bind()
    result = conn.execute(sa.text(f"PRAGMA table_info({table})"))
    columns = [row[1] for row in result]
    return column in columns


def upgrade() -> None:
    """Merge digital_io into sensor table using Single Table Inheritance."""

    # 1. Add new columns to sensor table (skip if already exists — idempotent)
    cols_to_add = {
        "sensor_type": "ALTER TABLE sensor ADD COLUMN sensor_type VARCHAR NOT NULL DEFAULT 'ANALOG'",
        "parent_id": "ALTER TABLE sensor ADD COLUMN parent_id INTEGER DEFAULT NULL",
        "is_system_wide": "ALTER TABLE sensor ADD COLUMN is_system_wide BOOLEAN NOT NULL DEFAULT 0",
        "di_type": "ALTER TABLE sensor ADD COLUMN di_type VARCHAR DEFAULT NULL",
        "trigger_on_max": "ALTER TABLE sensor ADD COLUMN trigger_on_max BOOLEAN NOT NULL DEFAULT 1",
        "trigger_on_min": "ALTER TABLE sensor ADD COLUMN trigger_on_min BOOLEAN NOT NULL DEFAULT 1",
    }
    for col_name, sql in cols_to_add.items():
        if not _column_exists("sensor", col_name):
            op.execute(sql)

    # 2. Set existing sensors as ANALOG
    op.execute("UPDATE sensor SET sensor_type = 'ANALOG' WHERE sensor_type = 'ANALOG' OR sensor_type IS NULL")

    # 3. Check if digital_io table exists before migrating
    conn = op.get_bind()
    tables = [r[0] for r in conn.execute(sa.text("SELECT name FROM sqlite_master WHERE type='table'"))]
    if "digital_io" in tables:
        # Migrate data from digital_io into sensor
        op.execute("""
            INSERT INTO sensor (
                sensor_type, name, unit, slave_id, register_address,
                register_type, data_type, data_format, coefficient,
                poll_interval, report_index,
                parent_id, is_system_wide, di_type,
                trigger_on_max, trigger_on_min,
                active, created_at
            )
            SELECT
                io_type,
                label,
                '',
                slave_id,
                address,
                CASE WHEN io_type = 'DI' THEN 'discrete_input' ELSE 'coil' END,
                'int16',
                'AB',
                '{}',
                3,
                0,
                sensor_id,
                0,
                di_type,
                trigger_on_max,
                trigger_on_min,
                active,
                created_at
            FROM digital_io
        """)

        # 4. Drop the old digital_io table
        op.drop_table('digital_io')


def downgrade() -> None:
    """Recreate digital_io table and move DI/DO rows back."""

    # 1. Recreate digital_io table
    op.create_table(
        'digital_io',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('sensor_id', sa.Integer(), nullable=False),
        sa.Column('io_type', sa.String(), nullable=False),
        sa.Column('label', sa.String(), server_default=''),
        sa.Column('slave_id', sa.Integer(), nullable=False),
        sa.Column('address', sa.Integer(), nullable=False),
        sa.Column('di_type', sa.String(), nullable=True),
        sa.Column('trigger_on_max', sa.Boolean(), server_default=sa.text('1'), nullable=False),
        sa.Column('trigger_on_min', sa.Boolean(), server_default=sa.text('1'), nullable=False),
        sa.Column('active', sa.Boolean(), server_default=sa.text('1'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
    )

    # 2. Move DI/DO rows from sensor back to digital_io
    op.execute("""
        INSERT INTO digital_io (
            sensor_id, io_type, label, slave_id, address,
            di_type, trigger_on_max, trigger_on_min, active, created_at
        )
        SELECT
            parent_id, sensor_type, name, slave_id, register_address,
            di_type, trigger_on_max, trigger_on_min, active, created_at
        FROM sensor
        WHERE sensor_type IN ('DI', 'DO')
    """)

    # 3. Delete DI/DO rows from sensor
    op.execute("DELETE FROM sensor WHERE sensor_type IN ('DI', 'DO')")

    # 4. Drop new columns (SQLite 3.35+)
    op.execute("ALTER TABLE sensor DROP COLUMN trigger_on_min")
    op.execute("ALTER TABLE sensor DROP COLUMN trigger_on_max")
    op.execute("ALTER TABLE sensor DROP COLUMN di_type")
    op.execute("ALTER TABLE sensor DROP COLUMN is_system_wide")
    op.execute("ALTER TABLE sensor DROP COLUMN parent_id")
    op.execute("ALTER TABLE sensor DROP COLUMN sensor_type")
