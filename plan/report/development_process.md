# Quy trình Phát triển Ứng dụng Biên (Edge App) - Data Logger

**Danh mục từ viết tắt**
*   **FRs:** Yêu cầu chức năng (Functional Requirements)
*   **NFRs:** Yêu cầu phi chức năng (Non-functional requirements)
*   **BFD:** Sơ đồ phân rã chức năng (Business Function Diagram)
*   **DFD:** Sơ đồ luồng dữ liệu (Data Flow Diagram)
*   **HIL:** Kiểm thử qua phần cứng thực/giả lập (Hardware-In-the-Loop)

---

## 0. Ngăn xếp Công nghệ (Tech Stack)
*   **Ngôn ngữ lập trình chính:** Python 3.12.
*   **Framework Giao diện (UI/GUI):** PySide6 (Qt for Python).
*   **Cơ sở dữ liệu (Database):** SQLite (Local/Embedded file).
*   **ORM & Migration DB:** SQLModel + Alembic latest.
*   **Giao tiếp công nghiệp:** `pymodbus`.
*   **Truyền tải & Lập lịch:** `Asyncz` + `asyncssh`.
*   **Hardware Access:** udev rules + dialout group.
*   **Quản lý bộ thư viện:** `uv`.
*   **Đóng gói & Chạy ngầm:** Linux `systemd`, đóng gói `.deb` file.

---

## 1. Khảo sát hệ thống
1.1 Khảo sát các dự án tương tự (Ứng dụng SCADA, IoT Edge Gateway)
1.2 Xác định yêu cầu ban đầu cho ứng dụng
*   1.2.1 Yêu cầu chức năng (FRs): Đọc Modbus, Giao diện UI PySide6, Xuất file txt, Gửi FTP theo Thông tư 10/2021/TT-BTNMT.
*   1.2.2 Yêu cầu phi chức năng (NFRs): Chạy 24/7 không tràn RAM, khả năng tự phục hồi khi mất điện, chống mòn ổ cứng/thẻ nhớ, tự kết nối lại mạng (timeout/retry).

## 2. Phân tích hệ thống
2.1 Các chức năng thu thập được từ quá trình khảo sát và phân tích nghiệp vụ
2.2 Gom nhóm chức năng (Nhóm Thu thập dự liệu, Nhóm Lưu trữ, Nhóm Truyền tải FTP, Nhóm UI/UX)
2.3 Sơ đồ phân rã chức năng (BFD)
2.4 Sơ đồ luồng dữ liệu (DFD)
*   2.4.1 DFD mức ngữ cảnh
*   2.4.2 DFD mức 1
*   2.4.3 DFD mức 2 (Chi tiết luồng QThread: Modbus -> Database -> GUI)
2.5 Sơ đồ hoạt động (Activity Diagram)
*   2.5.1 Sơ đồ luồng xử lý gửi FTP và cơ chế Retry khi mất mạng.
*   2.5.2 Sơ đồ vòng lặp đọc Modbus (Polling loop) và xử lý ngoại lệ khi đứt cáp.
2.6 Sơ đồ trạng thái (State Machine Diagram)
*   2.6.1 Trạng thái của thiết bị (Đang đo, Lỗi kết nối, Hiệu chuẩn) để hiển thị lên UI.
2.7 Đặc tả chi tiết từng Module.

## 3. Thiết kế hệ thống
3.1 Thiết kế kiến trúc tổng thể & Sơ đồ triển khai (Deployment Diagram)
*   Mô tả kết nối vật lý: Cảm biến (RS485) -> Raspberry Pi 4 -> Internet -> FTP Server.
3.2 Thiết kế chi tiết hệ thống
*   3.2.1 Sơ đồ Lớp (Class Diagram): Cấu trúc Database SQLModel, Worker, và bridge QML (`ApplicationController` / `*_Controller`, không dùng Qt Widgets).
*   3.2.2 Sơ đồ Tuần tự (Sequence Diagram): Cực kỳ quan trọng để mô tả giao tiếp Đa luồng (Worker Thread `emit signal` -> Main Thread cập nhật UI).
3.3 Thiết kế cơ sở dữ liệu (SQLite Schema, Thiết lập PRAGMA WAL & Memory Cache)
3.4 Thiết kế giao diện nguyên mẫu (Prototype UI: HTML tĩnh hoặc QML sketch; không dùng Qt Widgets Designer)
3.5 Các quy định và nguyên tắc (Coding convention, Xử lý Exception, Logging rules).

---
*(Phần Bổ sung cho Môi trường Công nghiệp & IoT)*

## 4. Xây dựng và Tích hợp (Implementation)
4.1 Xây dựng Lớp Lưu trữ (Database Manager & SQLModel ORM)
4.2 Xây dựng Lõi Background Workers (Modbus Polling Thread, FTP Upload Thread)
4.3 Xây dựng Giao diện (PySide6 QML: Views `.qml`, `Dialog`/`Popup` QML, biểu đồ Qt Charts trong QML nếu cần)
4.4 Tích hợp Đa luồng (Gắn kết Signal/Slot giữa Core và UI)

## 5. Kiểm thử và Đánh giá độ Bền bỉ (Testing & Validation)
5.1 Kiểm thử chức năng phần mềm (Unit Test / Dùng `modbus_slave.py` để giả lập trạm)
5.2 Kiểm thử HIL (Hardware-In-the-Loop): Kết nối thử bằng cáp USB-RS485 tới cảm biến thật.
5.3 Kiểm thử Rủi ro Hệ thống (Chaos Testing):
*   Rút cáp mạng đột ngột (Kiểm tra cơ chế retry FTP và lưu tạm pending).
*   Rút nguồn cáp điện đột ngột (Kiểm tra xem SQLite có bị corrupt hay không).
*   Rút/cắm lại cáp Modbus (Kiểm tra khả năng auto-reconnect của pymodbus).
5.4 Kiểm thử Stress Test 24/7 (Burn-in test liên tục trong 3-5 ngày).

## 6. Đóng gói và Triển khai (Deployment & Operations)
6.1 Chuẩn bị Môi trường Phần cứng (Thiết lập boot từ SSD cho Raspberry Pi 4).
6.2 Cấu hình OS/Linux (Cài đặt IP Tĩnh, vô hiệu hóa GUI thừa, thiết lập Pi Connect).
6.3 Đóng gói ứng dụng (Cập nhật `build-deb.sh` để tạo file `.deb` + cấu hình `systemd` service bắt đầu cùng hệ điều hành).
6.4 Lắp đặt, ban giao và hướng dẫn vận hành cho nhân viên trạm.