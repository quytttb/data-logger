"""Model Sensor — Cấu hình cảm biến Modbus & thông tin xuất báo cáo."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class Sensor(SQLModel, table=True):
    """Cấu hình cảm biến Modbus & thông tin xuất báo cáo."""

    __tablename__ = "sensor"

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True, description="Tên cảm biến (VD: Mức dầu)")
    unit: str = Field(description="Đơn vị đo (mg/L, °C, m,...)")

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

    # === Công thức quy đổi ===
    coefficient: Optional[str] = Field(
        default="{}",
        description="JSON hệ số công thức: {'a': 1.0, 'b': 0.0} → y = ax + b",
    )

    # === Alarm thresholds ===
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

    # === Báo cáo TT10 ===
    report_index: int = Field(
        default=0,
        description="Thứ tự cột khi xuất file TXT Phụ lục 15",
    )

    active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.now)
