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

    # === Cài đặt chung (General) ===
    time_format: str = Field(
        default="HH:mm:ss",
        description="Định dạng giờ: HH:mm:ss | hh:mm:ss AP",
    )
    date_format: str = Field(
        default="dd/MM/yyyy",
        description="Định dạng ngày: dd/MM/yyyy | yyyy-MM-dd | MM/dd/yyyy",
    )
    timezone: str = Field(
        default="UTC+7",
        description="Múi giờ hệ thống",
    )
    auto_sync_time: bool = Field(
        default=False,
        description="Tự động đồng bộ thời gian qua NTP",
    )
    buzzer_enable: bool = Field(
        default=False,
        description="Bật/tắt còi cảnh báo",
    )

    # === Cấu hình FTP ===
    ftp_address: str = Field(default="", description="Địa chỉ FTP Server")
    ftp_port: int = Field(default=21, description="Cổng kết nối FTP (mặc định 21)")
    ftp_username: str = Field(default="", description="Tài khoản đăng nhập")
    ftp_password: str = Field(
        default="",
        description="Mật khẩu đã mã hóa AES (Fernet)",
    )
    ftp_remote_path: str = Field(
        default="/",
        description="Đường dẫn thư mục trên FTP server",
    )
    ftp_prefix: str = Field(
        default="",
        description="Tiền tố tên tệp truyền tin",
    )

    # === Cấu hình Server / Truyền tin ===
    server_active: bool = Field(
        default=False,
        description="Kích hoạt truyền tin",
    )
    server_device_type: str = Field(
        default="Standard",
        description="Loại thiết bị (Standard...)",
    )
    server_name: str = Field(
        default="",
        description="Tên server truyền tin",
    )
    server_send_interval: int = Field(
        default=5,
        description="Tần suất gửi (phút)",
    )
    server_start_time: str = Field(
        default="00:00",
        description="Thời gian bắt đầu truyền",
    )
    server_base_folder: str = Field(
        default="",
        description="Thư mục cơ sở trên server",
    )
    server_time_folder: str = Field(
        default="yyyy/MM/dd",
        description="Định dạng thư mục thời gian",
    )
    server_file_suffix: str = Field(
        default="yyyyMMddHHmmss",
        description="Hậu tố tên tệp",
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

    # === Modbus TCP Server (xuất dữ liệu cho hệ tập trung / SCADA) ===
    modbus_tcp_enabled: bool = Field(
        default=False,
        description="Bật Modbus TCP Server để app tập trung đọc realtime",
    )
    modbus_tcp_port: int = Field(
        default=5020,
        description="Cổng lắng nghe TCP (mặc định 5020 để tránh privileged 502 trên Linux)",
    )
    modbus_tcp_bind: str = Field(
        default="0.0.0.0",
        description="Địa chỉ bind (0.0.0.0 = mọi interface)",
    )
    modbus_tcp_unit_id: int = Field(
        default=1,
        description="Unit ID (Slave ID ảo) trả về cho TCP client",
    )

    # === REST API (cấu hình từ xa cho Central App qua LAN) ===
    rest_api_enabled: bool = Field(
        default=False,
        description="Bật HTTP REST API để Central App đọc/ghi cấu hình từ xa",
    )
    rest_api_port: int = Field(
        default=8080,
        description="Cổng HTTP REST (mặc định 8080)",
    )
    rest_api_bind: str = Field(
        default="0.0.0.0",
        description="Địa chỉ bind REST API (0.0.0.0 = mọi interface)",
    )
    rest_api_token: str = Field(
        default="",
        description="Bearer token dùng cho REST API (rỗng = tự sinh khi bật lần đầu)",
    )
    config_revision: int = Field(
        default=1,
        description="Số revision cấu hình; tăng mỗi lần POST /config thành công (optimistic concurrency)",
    )

    # Giao diện
    ui_locale: str = Field(
        default="vi",
        description="Ngôn ngữ UI: vi | en",
    )
