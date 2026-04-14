## Plan: Data Logger Local Migration

Việc gạch bỏ hệ thống Cloud server sẽ giúp giảm chi phí duy trì, đơn giản hóa kiến trúc và tận dụng sức mạnh cấu hình của Raspi 4. 

**Steps**
1. **Thiết lập & Cấu hình Database cục bộ (Local DB) - *Phụ thuộc mã nguồn Cloud***
   - Tái cấu trúc các class DB Models từ SQLAlchemy (`cloud/api/models/`) sang dạng **SQLModel** mới gọn nhẹ hơn tại kiến trúc `local/`, tích hợp với Alembic (`cloud/api/migrations/`).
   - Chuyển cấu hình cơ sở dữ liệu từ PostgreSQL sang **SQLite** (tạo file `data.sqlite` trong thư mục cấu hình của Pi, ví dụ `/opt/data-logger/data/`) để không phải cài đặt và duy trì Postgres engine.

2. **Mô hình lập trình Đa luồng (Multi-threading) bằng PySide6**
   - Sự kết hợp hoàn hảo nhất cho ứng dụng Edge Công nghiệp 24/7 trên Pi là sử dụng **`QThread` + `QObject` worker pattern** của PySide6.
   - **Luồng chính (Main Thread):** Luôn giữ độc quyền để chạy giao diện (UI) mượt mà nhất bằng `QGuiApplication.exec()` kết hợp với `QQmlApplicationEngine`. Tuyệt đối không chạy hàm Sleep hay vòng lặp vô hạn ở đây.
   - **Luồng nền Đọc dữ liệu (Modbus Worker Thread):** Chạy độc lập `pymodbus`. Cứ mỗi chu kỳ sẽ phát tín hiệu (`emit signal`) chứa dữ liệu về cho các luồng khác.
   - **Luồng nền DB (Database Worker Thread):** Tránh việc ghi SQLite trực tiếp từ luồng chính (để đề phòng giật lag GUI khi đọc liên tục tần số cao). Thiết lập một QThread riêng với Queue (Hàng chờ) để tuần tự hóa các tác vụ `INSERT/UPDATE` độc lập vào SQLite.
3. **Chuyển đổi Sang Ổ Cứng SSD**
   - Viết lại DB schema sử dụng **SQLModel** để thay thế cho cấu trúc SQLAlchemy.
   - Chuyển từ PostgreSQL sang CSDL **SQLite**.
   - **ĐẶC BIỆT QUAN TRỌNG (Phần cứng):** Khuyến nghị triệt để việc loại bỏ hoàn toàn thẻ MicroSD và thay bằng **ổ cứng SSD cắm qua cổng USB 3.0** để cài đặt Hệ điều hành và chứa SQLite. SSD có sự bền bỉ về đọc/ghi (TBW) vượt trội trong môi trường 24/7 công nghiệp, giúp loại bỏ hoàn toàn rủi ro hỏng thẻ và mất dữ liệu.
   - **Cấu hình phần mềm:** Bật chế độ `PRAGMA journal_mode = WAL;` (Ghi trước, chống lock DB) và dùng RAM tính toán `PRAGMA temp_store = MEMORY;` như một lớp bảo vệ thứ 2, giúp tăng hiệu suất ghi song song
     - Bật `PRAGMA synchronous = NORMAL;` và dùng RAM để tính toán tạm `PRAGMA temp_store = MEMORY;` (giúp giảm số lần ghi vật lý xuống thẻ nhớ).

4. **Tích hợp File FTP nội bộ theo chuẩn Thông tư 10/2021/TT-BTNMT**
   - Đem thư mục cấu hình FTP và thuật toán tích/toán học (*formulas*) từ Cloud API sang qua local.
   - **Tuân thủ quy định môi trường**:
     - Định dạng file `TXT` phải chứa đúng 5 trường: *Thông số, Kết quả, Đơn vị, Thời gian (GMT+7), Trạng thái thiết bị* theo đúng Phụ lục 15.
     - Lập lịch gửi thời gian thực (chậm nhất mỗi 5 phút) qua tiến trình ngầm Asyncz. Dùng `asyncssh` để xử lý sFTP bất đồng bộ, nhẹ và cấu hình bảo mật (hỗ trợ SSH key) tốt hơn.
   - Thiết lập cấu trúc **Asyncz Scheduler** song song để gửi file TXT. Quá trình xử lý: Get DB Local -> Lưu Txt trên RAM `\tmp\` Pi -> Dùng `asyncssh` đẩy sFTP.
   - **Xử lý Cách ly Mạng & Truyền bù (Data Recovery)**:
     - **Timeout ngắn**: Cài đặt biến tự hủy FTP (`timeout=3-5s`) để tránh treo luồng khi rớt mạng công nghiệp.
     - **Tính năng bù dữ liệu**: Khi mạng mất, lưu tất cả file TXT chưa gửi thành công vào thư mục định tuyến `reports/pending/`. Khi mạng ổn định, hàm retry sẽ quét đẩy lại số liệu sao cho không thiếu file nào. Cảnh báo ra UI nếu rớt kết nối > 12 tiếng.

5. **Đóng gói và Cập nhật Systemd**
   - Chỉnh sửa `local/systemd/data-logger.service`. Lệnh `ExecStart` giờ đây sẽ là trình khởi chạy Uvicorn/Web server.
   - Sửa script `local/build-deb.sh` để đóng gói package debian mới bao gồm cả code đã build từ web, code API, các file utils và cấu hình SQLite.

**Relevant files**
- `local/main.py` — Sửa thành Server API & khởi tạo UI/Background modbus.
- `pyproject.toml` (quản lý bởi uv) — Bổ sung API utils và `sqlmodel`.
- `cloud/web/nuxt.config.ts` — Đổi config xuất frontend static.
- `local/systemd/data-logger.service` — Cập nhật entrypoint file dịch vụ.

**Verification**
1. **Kiểm tra App Local**: Chạy `python local/main.py`, truy cập truy cập web UI trên Pi.
2. **Kiểm thử Multi-task**: Xem log thiết bị, đảm bảo Modbus vẫn đọc 24/7 và ghi thành công vào DB SQLite mà Web API (FastAPI) không bị treo/block.
3. **Mô phỏng Truyền FTP**: Gửi thử 1 mẫu txt dữ liệu môi trường từ Pi qua một FTP Test Server, so khớp định dạng nội dung với bản cũ.

**Decisions**
- Quyết định: Gom chạy chung 1 tiến trình (Single Process, nhiều coroutines) cho cả Web API, Web Server tĩnh và Modbus Polling để dễ cập nhật, đóng gói.
- Quyết định: Dùng SQLite để không cần bảo trì hạ tầng DB, phù hợp cho edge computing.

**Further Considerations**
1. _Chuyển quyền Boot (Boot from USB):_ Việc cấu hình Pi 4 khởi động luôn (boot) từ SSD USB 3.0 sẽ cần thay đổi ROM cấu hình `raspi-config` cơ bản ở lần cài đặt đầu tiên. Phải truyền đạt lại quy trình này cho nhân viên lắp đặt tủ điện.
2. _Dự phòng cấu hình cài đặt:_ Khi hỏng thẻ MicroSD, khách có cần tính năng "Export Settings" cấu hình cài đặt ra một file Json (tải về máy tính qua Web) để dễ khôi phục về sau không?