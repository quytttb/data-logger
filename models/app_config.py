"""Model AppConfig — Cấu hình toàn cục của trạm (1 dòng duy nhất)."""

from typing import Optional

from sqlmodel import Field, SQLModel


class AppConfig(SQLModel, table=True):
    """Cấu hình toàn cục của trạm (chỉ 1 dòng duy nhất trong DB)."""

    __tablename__ = "app_config"

    id: Optional[int] = Field(default=None, primary_key=True)

    # === Thông tin Trạm ===
    station_code: str = Field(
        default="",
        description="Mã trạm theo quy định Sở TNMT",
    )
    station_name: str = Field(
        default="",
        description="Tên trạm quan trắc",
    )

    # === Cấu hình FTP ===
    ftp_address: str = Field(default="", description="Địa chỉ FTP Server")
    ftp_port: int = Field(default=22, description="Cổng kết nối (22 cho sFTP)")
    ftp_username: str = Field(default="", description="Tài khoản đăng nhập")
    ftp_password: str = Field(
        default="",
        description="Mật khẩu đã mã hóa AES (Fernet)",
    )
    ftp_remote_path: str = Field(
        default="/",
        description="Đường dẫn thư mục trên FTP server",
    )

    # === Cấu hình Polling ===
    poll_interval: int = Field(
        default=3,
        description="Chu kỳ đọc Modbus (giây)",
    )

    # === Cấu hình Serial (RS485) ===
    serial_port: str = Field(
        default="/dev/ttyUSB0",
        description="Cổng RS485 kết nối Modbus",
    )
    serial_baudrate: int = Field(
        default=9600,
        description="Tốc độ baud",
    )
    serial_bytesize: int = Field(
        default=8,
        description="Data bits (7 hoặc 8)",
    )
    serial_parity: str = Field(
        default="N",
        description="Parity check — N/E/O",
    )
    serial_stopbits: int = Field(
        default=1,
        description="Stop bits (1 hoặc 2)",
    )

    # Giao diện
    ui_locale: str = Field(
        default="vi",
        description="Ngôn ngữ UI: vi | en",
    )
