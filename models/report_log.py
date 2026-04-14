"""Model ReportLog — Nhật ký gửi file báo cáo TXT."""

from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class ReportLog(SQLModel, table=True):
    """Nhật ký gửi file báo cáo TXT, lưu lịch sử chi tiết từng lần."""

    __tablename__ = "report_log"

    id: Optional[int] = Field(default=None, primary_key=True)
    filename: str = Field(
        index=True,
        description="Tên file TXT (VD: 2026-04-06_14-30.txt)",
    )
    status: str = Field(
        default="pending",
        description="Trạng thái: pending / sent / failed",
    )
    retry_count: int = Field(
        default=0,
        description="Số lần đã thử gửi",
    )
    error_message: Optional[str] = Field(
        default=None,
        description="Nội dung lỗi chi tiết của lần gửi gần nhất",
    )
    created_at: datetime = Field(
        default_factory=datetime.now,
        description="Thời điểm tạo file TXT",
    )
    sent_at: Optional[datetime] = Field(
        default=None,
        description="Thời điểm gửi thành công",
    )
