# PHASE 1 - REPORT

## Tóm tắt nội dung thực hiện (Phase 1: Immediate & High Priority)

### Task 1: Tích hợp Alembic cho Database Schema Migrations ✅
- **pyproject.toml**: Đã bổ sung `alembic>=1.13` vào danh sách `dependencies`.
- Đã khởi tạo cấu trúc migrations bằng lệnh `alembic init migrations`.
- **migrations/env.py**: Đã cấu hình để import metadata từ `sqlmodel` (import toàn bộ models: `app_config`, `digital_io`, `report_log`, `sensor`, `sensor_data`) thay cho base mẫu của ORM cổ điển. Đồng thời liên kết tự động tới `DATABASE_URL` trong `core/database.py`.
- **Thực thi Migration Đầu tiên**: Đã tạo file revision đầu tiên bằng biến `-m "Initial schema"`.
- **Quản lý Vòng đợi Worker**: Đã thay thế subprocess `alembic upgrade head` bằng Alembic API chuẩn (`command.upgrade(alembic_cfg, "head")`) trong lớp `DatabaseWorker` để đảm bảo tương thích đa nền tảng và dễ debug.

### Task 2: Implement Heartbeat / Watchdog cho các Worker ✅
- Đã khai báo signal `heartbeat = Signal(str)` vào các class Worker cốt lõi (`ModbusWorker`, `DatabaseWorker`, `FtpWorker`) và tick mỗi 5s.
- **Watchdog Tích hợp**: Đã tạo cơ chế giám sát sử dụng `QTimer(interval=5000)` trong `MonitorController.py`.
- **Luồng xử lý Cảnh báo**: Khi bỏ qua 3 heartbeats liên tục (>6s/chu kỳ 5s định danh), watcher sẽ tự động gửi `watchdogAlert(str)` và stop/restart đồng bộ tiến trình thông qua `QTimer.singleShot(2000, self.start_polling)`.
- **UI QML**: Đã thêm property `watchdogStatus` hiển thị trạng thái realtime trên thanh Bottom/Monitor taskbar của ứng dụng. Báo *OK* hoặc đánh dấu *ERR: "Tên Worker"*.

## Next Steps
1. Đi vào **PHASE 2**: Tối ưu SQLite (hoàn thiện batch logger), Tối ưu QML data binding logic, Polling time Modbus và tinh chỉnh Kiosk mode trên hệ điều hành RPi.

*Báo cáo được khởi tạo tự động.*