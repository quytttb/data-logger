# 4. Xây dựng và Tích hợp (Implementation)

Dựa trên bản thiết kế chi tiết ở Bước 3, chương này trình bày quá trình hiện thực hóa toàn bộ ứng dụng **Data Logger** thành mã nguồn Python. Quá trình lập trình được chia thành 4 giai đoạn độc lập nhằm đảm bảo tiến độ và dễ dàng kiểm soát lỗi.

## 4.1 Khởi tạo Dự án & Môi trường

Thay vì sử dụng `pip` hay `poetry` truyền thống, dự án này áp dụng **`uv`** làm Package Manager (trình quản lý gói) thế hệ mới.
- **Lý do:** Tốc độ cài đặt siêu tốc bằng Rust, tự động quản lý phiên bản Python độc lập (không làm hỏng môi trường Linux OS gốc trang bị trên Raspberry Pi).
- **Dependencies chính:** `pyside6` (giao diện), `sqlmodel` (ORM), `pymodbus` (giao tiếp RS485), `asyncssh` (gửi sFTP), và `cryptography` (mã hóa mật khẩu).
- Toàn bộ codebase được dịch chuyển vào thư mục gốc `app/`, giải quyết dứt điểm tình trạng phân mảnh mã nguồn ở các phiên bản cũ.

---

## 4.2 Giai đoạn 1: Tầng Lưu trữ (Core Database & Models)

Lớp dữ liệu là nền móng của hệ thống, được thiết kế để chịu tải ghi liên tục 24/7 mà không làm "nghẽn" giao diện.

### 4.2.1 Cấu hình SQLite Công nghiệp
Mã nguồn: `app/core/database.py`

Thay vì dùng SQLite mặc định, hệ thống "gắn cứng" các rule cấu hình cấp thấp (PRAGMA) ngay từ lúc khởi tạo `create_engine`:
- `PRAGMA journal_mode = WAL;`: (Write-Ahead Logging) Mở khóa chế độ song song. Worker ghi dữ liệu xuống đĩa (Writer) và GUI truy xuất lịch sử (Reader) hoạt động độc lập, loại bỏ hoàn toàn lỗi văng app `OperationalError: database is locked`.
- Cấu hình dùng bộ nhớ RAM cho file tạm (`temp_store = MEMORY`) để giảm tối đa chu kì bào mòn ổ cứng SSD/Thẻ nhớ của Pi.

### 4.2.2 Mapping SQLModel
Mã nguồn: `app/models/*.py`

Triển khai 4 class Model ánh xạ trực tiếp thành các bảng dữ liệu thực tế bằng SQLModel:
1. `AppConfig`: Bảng 1-dòng cấu hình trạm đo, lưu trữ cả thông tin truy cập FTP.
2. `Sensor`: Khai báo chi tiết thiết bị Modbus (Slave ID, thanh ghi, Endianness).
3. `SensorData`: Lưu trữ log giá trị đã quy đổi (`value`) và giá trị thô Modbus (`raw_value`).
4. `ReportLog`: Nhật ký gửi báo cáo sFTP, bao gồm thuật toán theo dõi số lần thử lại (`retry_count`).

### 4.2.3 Lõi Nghiệp vụ Đặc thù
1. **Module `crypto.py`**: Mã hóa AES toàn bộ mật khẩu hệ thống (như FTP Password) bằng thư viện `Fernet`. Sinh tự động `secret.key` vào file config ẩn bảo vệ tĩnh.
2. **Module `formula.py`**: Parser chuyển đổi chuỗi JSON coefficient thành thuật toán toán học tuyến tính ($y = ax + b$) hoặc đa thức bậc cao.

---

## 4.3 Giai đoạn 2: Trái tim Hệ thống (Background Workers)

Bộ xử lý nền được phân nhỏ ra 3 trình làm việc độc lập kế thừa từ `QObject`, mỗi trình chạy trên một `QThread` riêng biệt và giao tiếp thuần tuý bằng `Qt Signals`.

### 4.3.1 ModbusWorker
Mã nguồn: `app/workers/modbus_worker.py`
- Duy trì Connection liên tục qua cổng COM/ttyUSB.
- Code giải quyết các bài toán hóc búa của kỹ thuật số như Signed/Unsigned INT16, xử lý Endianness byte swap ở tín hiệu Float32 (ABCD, CDAB, BADC, DCBA).
- Khi có vòng dữ liệu mới, ngay lập tức phát sóng signal `data_ready(dict)`.

### 4.3.2 DatabaseWorker
Mã nguồn: `app/workers/database_worker.py`
- Thay vì mỗi lần đọc Modbus lại gọi lệnh đĩa ghi Database 1 lần (gây nghẽn IOPS), Worker này tiếp nhận dữ liệu qua `Queue` thread-safe.
- Chỉ thực hiện `session.add_all()` và `commit()` khi gom đủ batch lớn (Batch INSERT), tăng tuổi thọ máy vật lý và hiệu suất app.

### 4.3.3 FtpWorker & TxtGenerator
Mã nguồn: `app/workers/ftp_worker.py`, `app/core/txt_generator.py`
- Trình tạo định dạng `TxtGenerator`: Group dữ liệu Modbus theo từng cụm Datetime, sắp xếp đúng cột khai báo `report_index` khớp 100% chuẩn Phụ lục 15.
- Trình gửi `FtpWorker`: Upload bất đồng bộ qua giao thức sFTP bằng `asyncssh`. Nếu rớt kết nối mạng, Worker dán nhãn file thành dạng `pending`/`failed`, thuật toán vòng lặp sau sẽ tự lôi ra thử cắm cờ gửi lại (Auto Retry).

---

## 4.4 Giai đoạn 3: Đội hình Giao diện (PySide6 QML)

Mã nguồn: Thư mục `app/ui/qml/` (View) và `app/ui/*_controller.py` (QObject bridge).

Thay vì giao diện Tkinter hoặc Qt Widgets, ứng dụng dùng **QML** (`QQmlApplicationEngine`) với các tab chính tách file `.qml`.

1. **`DashboardView.qml`**: Lưới/card realtime; `TableView` hoặc `GridView` QML phối màu; thanh trạng thái & cảnh báo kết nối thiết bị — dữ liệu qua `DashboardController` (property/model).
2. **`HistoryView.qml`**: Bộ lọc thời gian bằng control QML (DatePicker tùy biến hoặc tổ hợp trường ngày giờ); bảng lịch sử lazy-load; nút xuất CSV gọi `@Slot` trên `HistoryController`.
3. **`SettingsView.qml`**: Form cấu hình trạm — `TextField`, `ComboBox`, `SpinBox` QML; lưu qua `SettingsController` xuống SQL, không hard-code trong QML.

---

## 4.5 Giai đoạn 4: Điểm nối Trung tâm (Integration)

Mã nguồn: `app/main.py` (khởi tạo `QGuiApplication`, `QQmlApplicationEngine`) và lớp điều phối kiểu `ApplicationController` (nếu tách file) nối Worker ↔ QML.

Thay vì cửa sổ Widget, **`ApplicationController`** (hoặc logic tương đương trong `main.py`) đóng vai "Bộ phận điều phối": đăng ký context property cho QML, khởi chạy Worker trên `QThread`.
- Khởi động đồng thời các `QThread` Worker và gắn vào điều phối.
- Nối Signals: đón `data_ready` từ Modbus → cập nhật property/controller → QML binding refresh tab Dashboard; đồng thời đẩy vào Queue cho `DatabaseWorker`.

File khởi chạy gốc `main.py` nạp `Main.qml`, áp **theme QML** (palette + `QtQuick.Controls` style) cho màn cảm ứng tủ điện, log xoay ngày, và đưa app vào môi trường Production.
