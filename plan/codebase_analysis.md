# Báo cáo Phân tích Tổng thể Mã nguồn (Codebase Analysis)
*Ngày phân tích: Tháng 4/2026*

Tài liệu này cung cấp cái nhìn tổng quan về toàn bộ kho mã nguồn hiện tại của dự án Data Logger, bao gồm cả phân hệ Cloud (`cloud/`) và Local (`local/`), nguyên bản trước khi thực hiện quy hoạch lại thành Kiến trúc Data Logger (100% Local).

---

## 1. Phân hệ Cloud (`cloud/`)
Là một hệ thống Web App Client-Server tiêu chuẩn, đảm nhận vai trò lưu trữ tập trung, cấp phát API, sinh báo cáo và giao diện người dùng để quản lý thiết bị từ xa.

### 1.1. Backend API (`cloud/api/`)
Được xây dựng trên nền tảng **FastAPI**, kết nối cơ sở dữ liệu **PostgreSQL** qua **SQLAlchemy** và quản lý cấu trúc DB bằng **Alembic**.
*   **`models/` & `schemas/`:** Định nghĩa toàn bộ lõi dữ liệu của hệ thống: cấu hình Trạm (master, member), Cảm biến (sensor_data, formula), cấu hình FTP của Sở TNMT (sensor_ftp_mapping), API Key bảo mật.
*   **`routers/`:** Cung cấp các RESTful API endpoints. Nổi bật là `generate_txt.py` và `report_file.py` chịu trách nhiệm render file báo cáo.
*   **`utils/`:** Thư mục chứa các module nghiệp vụ cốt lõi:
    *   `/ftp/`: Kết nối và truyền tải file.
    *   `/formula/`: Công thức nội suy/chuyển đổi dữ liệu thô (raw) sang dữ liệu tiêu chuẩn.
    *   `/report_handler/`: Trình tạo định dạng báo cáo.
*   **`generated_files/`:** Nơi chứa tạm các file txt chuẩn bị gửi FTP (cần đặc biệt chú ý khi chuyển xuống thiết bị nhúng vì lý do tuổi thọ thẻ nhớ).

### 1.2. Frontend Web (`cloud/web/`)
Xây dựng trên nền tảng **Vue 3 / Nuxt 3** với TypeScript.
*   **Đặc điểm:** Quản lý giao diện hiển thị danh sách thiết bị, xem biểu đồ, logs, và cài đặt các tham số FTP.
*   Giao tiếp với Backend qua tiêu chuẩn REST API.

---

## 2. Phân hệ Local (`local/`)
Là một agent/worker chạy sát phần cứng (Raspberry Pi/Industrial PC), có nhiệm vụ thu thập, tạm lưu và đẩy dữ liệu lên hệ thống Cloud.

### 2.1. Cấu trúc Core Python (`local/`)
*   **`main.py` & `modbus.py`:** Vòng lặp chính, đảm nhận việc khởi tạo kết nối **Modbus RTU (serial)** tới PLC hoặc cảm biến vật lý (TCP không dùng trong kiến trúc Data Logger hiện tại).
*   **`services/`:** 
    *   `data_collector.py`: Quản lý nghiệp vụ tuần tự hóa việc thu thập số liệu theo chu kỳ.
    *   `api_client.py`: Client HTTP để đẩy ngược (POST) số liệu lên `cloud/api/`.
    *   `local_db.py`: Hệ quản trị DB biên (có thể là SQLite) hoạt động như một bộ đệm (cache/buffer) phòng khi rớt mạng vật lý.
    *   `network.py` & `port_checker.py`: Tiện ích kiểm tra tính sẵn sàng của kết nối mạng và Serial Port (COM).

### 2.2. Môi trường & Triển khai
*   **`systemd/`:** Cung cấp file `data-logger.service` để chạy ứng dụng như một daemon Linux, tự khởi động cùng OS.
*   **`build-deb.sh` & `debian/`:** Bộ công cụ đóng gói toàn bộ agent thành file `.deb` chuẩn của Debian/Ubuntu, giúp khách hàng (nhân viên hiện trường) cài đặt dễ dàng bằng dòng lệnh `apt install`.
*   **`simulator/`:** Chứa script `modbus_slave.py` để giả lập thiết bị Modbus, phục vụ cho việc test logic khi không có cảm biến vật lý.
*   **`docs/`:** Chứa định hướng nâng cấp rất tốt như `PLAN-pyside6-migration.md` – chứng tỏ dự án đã nhắm tới việc tự chủ giao diện (GUI) ngay trên thiết bị biên.

---

## 3. Đánh giá sự chồng chéo & Điểm nghẽn (Bottlenecks)

Khi nhìn vào bức tranh tổng thể, việc thiết kế "Cloud + Local" hiện nay tạo ra các điểm dư thừa nếu áp dụng vào kiến trúc "Data Logger":
1.  **Dữ liệu đi đường vòng (Round-trip Data):** Cảm biến sinh dữ liệu -> Local đọc -> Local POST lên Cloud -> Cloud lưu DB -> Cloud Extract tải về file txt -> Cloud gửi FTP về Sở (vốn dĩ ở dưới đất). Đường cong truyền tải này gây tốn băng thông, chi phí thuê server và rủi ro rớt mạng tại thao tác POST.
2.  **Sự phân mảnh Logic:** Tính toán công thức (formulas) và sinh file txt đang nằm trên Server. Nếu Pi rớt kết nối mạng Cloud, Pi hoàn toàn "mù tịt", không thể tự sinh file txt đẩy về FTP trực tiếp cho Sở TNMT.
3.  **Tỷ lệ quá tải Cấu hình Server:** Server sẽ sụp đổ hoặc tốn nhiều tiền bảo trì nếu số lượng thiết bị Local (số node) tăng lên 1,000 trạm, vì mỗi trạm đều push API liên tục mỗi 3-5 giây.

---

## 4. Định hướng Hợp nhất (Merge Strategy) cho Data Logger

Sau khi phân tích, đây là các tài nguyên cần được **bốc tách (cherry-pick)** từ thư mục `cloud/` để "cấy ghép" trực tiếp vào `local/` nhằm tạo nên siêu ứng dụng độc lập (Monolith Industrial App):

*   **Models & Database:** Lấy toàn bộ `cloud/api/models/` hợp nhất với `local/services/local_db.py` (khuyến nghị viết lại bằng **SQLModel** thay vì SQLAlchemy thuần để rút gọn mã và type-safe trực quan).
*   **Nghiệp vụ FTP & Formula:** Bứng toàn bộ logic từ `cloud/api/utils/ftp/` và `formula/` nhúng vào pipeline của `local/services/data_collector.py` (hoặc tạo một worker mới).
*   **Giao diện & Cài đặt:** Bỏ qua mã nguồn React/Vue (Nuxt) nặng nề của `cloud/web/`. Dùng hệ thống Python GUI hiện hữu (chuyển đổi sang **PySide6 QML**) để vuốt/chạm mượt mà, thay thế bảng điều khiển trực quan. Tận dụng `local/config/settings.py` lưu file cài đặt.
*   **Đóng gói (Deployment):** Chỉ cần duy trì tiếp vòng đời của file `build-deb.sh` hiện tại nhưng gói thêm các module Database và GUI mới vào.