# 1. Khảo sát hệ thống

## 1.1 Khái quát mục đích khảo sát
Việc xây dựng một hệ thống phần mềm **Data Logger** chạy cục bộ trên môi trường Linux kết hợp cả giao tiếp công nghiệp (Modbus/RS485), cơ sở dữ liệu (`SQLite`) và giao diện đồ họa người dùng (`PySide6`) là một thách thức lớn. Hệ thống phải đảm bảo hoạt động ngầm (daemon) liên tục 24/7 mà giao diện không bao giờ bị "đóng băng" (freeze).
Vì hầu hết các phần mềm công nghiệp SCADA/HMI là mã nguồn đóng, việc tham khảo kiến trúc từ các dự án Open-Source đã thực địa thành công trên GitHub là rất cần thiết để tìm ra "Thiết kế chuẩn" (Pattern).

## 1.2 Khảo sát các giải pháp tham chiếu (GitHub Repos) & Bóc tách Mã nguồn
Dưới đây là các cấu trúc lõi có giá trị nhất được bóc tách trực tiếp từ mã nguồn thực tế:

### 1. [Joghur/modbus-reader](https://github.com/Joghur/modbus-reader)
*   **Đặc điểm:** Hệ thống Python thuần (`pymodbus` + `SQLite`) cực kì mạnh để đọc và insert dữ liệu ngầm không giao diện.
*   **Mã nguồn lõi ứng dụng (Code-insights):**
    *   **Cơ chế Config-Driven:** Tại `start.py`, chương trình không nạp cứng thông số mà đọc cấu hình qua các file (`config_database.json`, `config_modbus.json`,...). Mọi định tuyến thanh ghi đều được tùy biến sinh động bởi cài đặt mà không cần sửa Core code.
    *   **Vòng lặp Data-logging ngầm:** Quản lý cơ chế vòng lặp Background chạy độc lập siêu tốt để không gây Memory Leak.

### 2. [optio50/Victron_Modbus_TCP](https://github.com/optio50/Victron_Modbus_TCP)
*   **Đặc điểm:** Ứng dụng quản trị truy vấn Modbus cho inverter biến tần Victron (repo tham chiếu tên TCP; **Data Logger chỉ triển khai Modbus RTU** — pattern vòng lặp kháng lỗi áp dụng cho RTU).
*   **Mã nguồn lõi ứng dụng (Code-insights):**
    *   **Cơ chế Keep-Alive & Quản lý mất gói tin:** Đào sâu vào `MODBUS_Example.py`, vòng lặp vô biên `while True:` được gói bởi thủ thuật bắt lỗi Modbus cực khôn khéo. Khi đọc cổng Serial bị lỗi/nhiễu từ trường, hệ thống trả về `AttributeError`. Code ngay lập tức nhảy tới block `except` và dùng lệnh `continue` bắt đầu một vòng lặp tiếp theo, giúp App không bao giờ bị Crash. Thiết kế này bắt buộc phải tích hợp vào worker của Pi.
    *   **Tính toán số âm ngầm:** Bóc tách được logic chuyển đổi bit số nguyên: `if value > 32767: value -= 65536`. Thuật toán chuyển đổi unsigned thành signed 16-bit này sẽ cài thẳng vào bộ công cụ Formula Engine của chúng ta.

### 3. [SHMModbus/shm_modbus_gui](https://github.com/SHMModbus/shm_modbus_gui)
*   **Đặc điểm:** Một giao diện Qt chuyên biệt theo dõi thông số Modbus.
*   **Mã nguồn lõi ứng dụng (Code-insights):**
    *   **Cấu trúc thư mục định hướng quy mô lớn:** Cấu trúc phân mảnh giữa lớp logic (`src`, `MBConfig.py`, `InspectSHM_*`) và thư mục `ui` (QML + controller QObject), tương tự tách Model khỏi View. Tham chiếu dự án hiện tại: `Main.qml` / `*_controller.py` thay cho `MainWindow.py` kiểu Widgets.

### 4. Official Qt for Python Modbus Client & [yjg30737/pyqt-database-example](https://github.com/yjg30737/pyqt-database-example)
*   **Điểm sẽ ứng dụng:** Cách đổ dữ liệu SQLite khổng lồ lên phần Chart vẽ biểu đồ trên PySide6 thông qua cấu trúc QThread kết hợp chuẩn `Qt Signals/Slots`. Xử lý được bài toán CSDL không bị `Database locked` khi người dùng ấn vào tab "Đồ thị Lịch sử" để select trong khi bộ logger phía sau vẫn đang liên tục `INSERT`.

---

## 1.3 Nhận định & Xác định Yêu cầu ban đầu (FRs & NFRs)
Từ những đặc tính xuất sắc thu nhặt từ bóc tách codebase, mô hình ứng dụng **Data Logger** (Data Logger Architecture) được chốt hạ các yêu cầu:

### Yêu cầu chức năng (Functional Requirements - FRs)
- **Modbus RTU:** Hỗ trợ đọc Modbus RTU (Serial / USB-RS485 trên Pi). **Modbus TCP** không nằm trong phạm vi phiên bản hiện tại (có thể bổ sung sau). Cấu hình thanh ghi qua SQLite + UI (tương đương mục tiêu “config-driven” của các repo tham chiếu).
- **Trực quan:** Hiển thị số liệu Real-time tại Tab trang chủ và hỗ trợ vẽ Chart Đồ thị mượt mà trên framework PySide6.
- **Tuân thủ TNMT:** Cỗ máy tạo Báo cáo trích xuất DB và ghi thành file `.txt` đáp ứng format nghiêm ngặt Phụ lục Thông tư 10/2021 TTT-BTNMT.
- **Upload sFTP ngầm:** Tiến trình lập lịch qua `Asyncz` giúp đẩy ngầm file tới chi Cục môi trường.

### Yêu cầu phi chức năng (Non-Functional Requirements - NFRs)
- **Zero-Block Decoupling:** Giao diện Main/Master Thread không bao giờ bị đứng/giật kể cả khi cáp vật lý bị rút hay mạng Viettel/VNPT bị nghẽn (ứng dụng `Signals/Slots` triệt để).
- **Silent Fault-Tolerance:** Không sinh lỗi Panic Crash. Lỗi mất gói Modbus chỉ dẫn đến cảnh báo Status đỏ trên UI (`except AttributeError: continue`). Tương tự với sFTP.
- **Hardware Endurance:** SQLite tích hợp chế độ PRAGMA kết hợp với Batch Insert ở luồng SQLModel xử lý bộ nhớ ảo (WAL Memory/TempStore) để chống đứt đoạn hoặc làm mòn ở ổ cứng SSD độ bền công nghiệp.
