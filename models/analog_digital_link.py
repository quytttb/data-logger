"""AnalogDigitalLink — liên kết sensor ANALOG ↔ DI/DO.

Rules:
  - DI: một DI có thể link với nhiều analog (một row mỗi cặp analog+DI).
  - DO: một DO link với tối đa một analog (được enforce ở application layer).
  - UNIQUE(analog_sensor_id, digital_sensor_id) tránh link trùng.
"""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class AnalogDigitalLink(SQLModel, table=True):
    __tablename__ = "analog_digital_link"

    id: Optional[int] = Field(default=None, primary_key=True)

    analog_sensor_id: int = Field(
        foreign_key="sensor.id",
        description="FK → ANALOG sensor",
    )
    digital_sensor_id: int = Field(
        foreign_key="sensor.id",
        description="FK → DI or DO sensor",
    )

    # DI link: status code for TT10 report, NULL = not configured
    di_type: Optional[str] = Field(
        default=None,
        description="DI only: TT10 status code for this (analog, DI) pair (00/01/02/03...)",
    )

    # DO link: alarm trigger conditions
    trigger_on_max: bool = Field(
        default=True,
        description="DO only: activate relay when analog >= max_threshold",
    )
    trigger_on_min: bool = Field(
        default=True,
        description="DO only: activate relay when analog <= min_threshold",
    )

    created_at: datetime = Field(default_factory=datetime.now)
