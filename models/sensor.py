"""Model Sensor — Unified Modbus point: Analog sensor, Digital Input, or Digital Output.

Single Table Inheritance — a single `sensor` table stores all three types:
  - ANALOG: Standard analog sensor (pH, Temp, etc.).
  - DI: Digital Input — reads a discrete status (float switch, door sensor).
  - DO: Digital Output — writes a relay/buzzer/lamp controlled by alarm logic.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from sqlmodel import Field, SQLModel


class SensorType(str, Enum):
    """Discriminator for the Sensor model."""
    ANALOG = "ANALOG"
    DI = "DI"
    DO = "DO"


class Sensor(SQLModel, table=True):
    """Unified Modbus point configuration — Analog / DI / DO."""

    __tablename__ = "sensor"

    id: Optional[int] = Field(default=None, primary_key=True)

    # === Discriminator ===
    sensor_type: str = Field(
        default=SensorType.ANALOG,
        description="Point type: ANALOG, DI, or DO",
    )

    name: str = Field(index=True, description="Tên cảm biến (VD: Mức dầu)")
    unit: str = Field(default="", description="Đơn vị đo (mg/L, °C, m,...)")

    # === Cấu hình Modbus ===
    slave_id: int = Field(description="Địa chỉ Slave trên bus RS485")
    register_address: int = Field(description="Địa chỉ thanh ghi bắt đầu")
    register_type: str = Field(
        default="holding",
        description="Loại thanh ghi: 'holding' hoặc 'input'",
    )
    data_type: str = Field(
        default="int16",
        description="Kiểu dữ liệu: int16 / uint16 / float32",
    )
    data_format: str = Field(
        default="AB",
        description="Thứ tự byte (Endianness): AB / BA / ABCD / CDAB",
    )

    # === Công thức quy đổi (ANALOG only) ===
    coefficient: Optional[str] = Field(
        default="{}",
        description="JSON hệ số công thức: {'a': 1.0, 'b': 0.0} → y = ax + b",
    )

    # === Alarm thresholds (ANALOG only) ===
    min_threshold: Optional[float] = Field(
        default=None,
        description="Alarm when value <= this (None = disabled)",
    )
    max_threshold: Optional[float] = Field(
        default=None,
        description="Alarm when value >= this (None = disabled)",
    )

    # === Chu kỳ đọc riêng ===
    poll_interval: int = Field(
        default=3,
        description="Chu kỳ đọc riêng cho cảm biến (giây)",
    )

    # === Báo cáo TT10 (ANALOG only) ===
    report_index: int = Field(
        default=0,
        description="Thứ tự cột khi xuất file TXT Phụ lục 15",
    )

    # === Hierarchy (DI/DO → Parent Analog Sensor) ===
    parent_id: Optional[int] = Field(
        default=None,
        foreign_key="sensor.id",
        description="ID of the parent Analog sensor (NULL = standalone/top-level)",
    )
    is_system_wide: bool = Field(
        default=False,
        description="True if this is a system-wide DI/DO (not attached to any analog sensor)",
    )

    # === DI-specific: Status code for TT10 report ===
    di_type: Optional[str] = Field(
        default=None,
        description="Mã trạng thái báo cáo phụ lục (00, 01, 02, 03...). NULL nếu là ANALOG hoặc DO.",
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
