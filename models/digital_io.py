"""Model DigitalIO — Digital Input/Output configuration per sensor.

Each sensor (Analog) can have 0..N associated Digital I/O channels.
- DI (Digital Input):  Read-only status (e.g. float switch, door sensor).
- DO (Digital Output): Writable relay/buzzer/lamp controlled by alarm logic.
"""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class DigitalIO(SQLModel, table=True):
    """A single Digital I/O channel linked to a sensor."""

    __tablename__ = "digital_io"

    id: Optional[int] = Field(default=None, primary_key=True)
    sensor_id: int = Field(foreign_key="sensor.id", index=True)

    # "DI" or "DO"
    io_type: str = Field(
        description="Channel type: 'DI' (Digital Input) or 'DO' (Digital Output)",
    )

    label: str = Field(
        default="",
        description="Display label (e.g. 'Buzzer', 'Float switch', 'Warning lamp')",
    )

    # === Modbus addressing ===
    slave_id: int = Field(
        description="Modbus slave address of the I/O module",
    )
    address: int = Field(
        description="Coil/Discrete-input address on the slave device",
    )

    # === Status code (DI only) ===
    di_type: Optional[str] = Field(
        default=None,
        description="Mã trạng thái báo cáo phụ lục (00, 01, 02, 03...). NULL nếu là DO.",
    )

    # === DO-specific: alarm trigger condition ===
    trigger_on_max: bool = Field(
        default=True,
        description="DO only: activate when sensor value >= max_threshold",
    )
    trigger_on_min: bool = Field(
        default=True,
        description="DO only: activate when sensor value <= min_threshold",
    )

    active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.now)
