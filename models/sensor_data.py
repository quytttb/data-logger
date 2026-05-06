"""Model SensorData — Dữ liệu quan trắc realtime."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class SensorData(SQLModel, table=True):
    """Dữ liệu quan trắc realtime, ghi nhận theo chu kỳ polling."""

    __tablename__ = "sensor_data"

    id: Optional[int] = Field(default=None, primary_key=True)
    sensor_id: int = Field(foreign_key="sensor.id", index=True)
    value: Optional[float] = Field(
        default=None,
        description="Giá trị đã quy đổi qua công thức",
    )
    raw_value: Optional[int] = Field(
        default=None,
        description="Giá trị thô đọc từ thanh ghi Modbus",
    )
    status: Optional[str] = Field(
        default=None,
        description="Mã trạng thái thiết bị (00, 01, 02, 03..)",
    )
    recorded_at: datetime = Field(
        default_factory=datetime.now,
        index=True,
        description="Thời điểm ghi nhận (dùng để truy vấn lịch sử)",
    )
