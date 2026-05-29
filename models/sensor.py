"""Model Sensor — Unified Modbus point: Analog sensor, Digital Input, or Digital Output.

All three types are top-level rows (no parent hierarchy):
  - ANALOG: Standard analog sensor (pH, Temp, etc.).
  - DI: Digital Input — reads a discrete status (float switch, door sensor).
        Linked to ANALOG sensors via AnalogDigitalLink (one DI → many analogs).
  - DO: Digital Output — relay/buzzer driven by alarm logic.
        Linked to at most one ANALOG via AnalogDigitalLink.
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
        description="Thứ tự byte (Endianness): AB / BA / ABCD / CDAB / BADC / DCBA",
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

    # === DI/DO relationship: managed via AnalogDigitalLink table ===
    # di_type kept as legacy column (always NULL for new sensors; source of truth = link)
    di_type: Optional[str] = Field(
        default=None,
        description="Legacy — always NULL for new sensors. di_type per (analog,DI) pair lives in AnalogDigitalLink.",
    )

    active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.now)
