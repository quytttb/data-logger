# Data Logger

Ứng dụng giám sát cảm biến công nghiệp **chỉ triển khai và chạy trên Raspberry Pi 4** (GUI cảm ứng, Modbus, SQLite).  
Hỗ trợ tích hợp phần cứng đọc dữ liệu qua **Modbus RTU**, lưu trữ liên tục với **SQLite (WAL)**, hiển thị biểu đồ realtime thông qua **PySide6/QML**, và tự động kết xuất **CSV/TXT** hoặc đồng bộ lên hệ thống máy chủ bằng **FTP/sFTP/MQTT**.

Đặc biệt tự hào với hệ thống **CI/CD và OTA Updater**, cho phép nâng cấp phiên bản phần mềm từ xa mà không cần thay thẻ nhớ hoặc khởi động lại bằng rsync thủ công.

---

## Tính năng

| Module | Mô tả |
|---|---|
| **Modbus Tester** | Kiểm tra kết nối cổng serial, quét slave ID, đọc/ghi thủ công |
| **Cài đặt** | Cấu hình thông số trạm, giao thức Modbus, danh sách cảm biến, FTP server, MQTT, và cập nhật OTA |
| **Dashboard** | Polling tự động, hiển thị giá trị realtime, tự động tính toán qua công thức tuyến tính/đa thức `y = ax + b` |
| **Lịch sử** | Tra cứu dữ liệu quá khứ theo dải thời gian, cho phép kết xuất CSV (UTF-8 BOM) |
| **Báo cáo** | Sinh file báo cáo TXT (Chuẩn Phụ lục 15 - TT10/2021) và gửi định kỳ tự động qua sFTP |
| **Bảo mật** | Mã hóa an toàn mật khẩu (AES-128 Fernet) lưu trữ dưới database |

---

## Yêu cầu hệ thống

- **Phần cứng**: Raspberry Pi 4/5 (ARM64), màn hình cảm ứng 7", USB-RS485 Dongle.
- **OS**: Raspberry Pi OS 64-bit (Bookworm trở lên)
- **Môi trường chạy**: App chạy trực tiếp dưới dạng **Binary Standalone** (biên dịch bằng Nuitka) thông qua Systemd. Do thiết lập này, **Không khuyến khích chạy trực tiếp chế độ Production trên máy dev (Windows/Mac)**.

---

## CI/CD & OTA Workflow (Quy trình triển khai)

Dự án này sử dụng kiến trúc **Tích hợp liên tục và Triển khai tự động (Continuous Deployment - CI/CD)** mạnh mẽ tích hợp sâu vào GitHub Actions.

### 1. Trên máy phát triển (Laptop/PC)
File `deploy.sh` giờ đây đóng vai trò như một **App Manager Interactive** giúp tự động hóa quá trình đẩy code lên Pi để build:

1. Chạy lệnh:
   ```bash
   ./deploy.sh
   ```
2. Chọn Option `1` (Release phiên bản mới).
3. Nhập số Version (Ví dụ: `v1.0.0`).
4. Script sẽ tự động tạo Git Tag và vòng lặp `git push origin v1.0.0`.

### 2. Trên GitHub Actions
Ngay khi có một Tag `v*.*.*` mới được đẩy lên, Github Actions sẽ:
- Trigger workflow `ci-cd.yml` (Đã cấu hình sử dụng môi trường Node.js 24 native).
- Đẩy yêu cầu lệnh Build về lại một **Self-Hosted Runner (Máy Raspberry Pi 4 ARM64)**.
- Raspberry Pi tự động chạy `Nuitka3` biên dịch toàn bộ source code thành 1 file nhị phân duy nhất (`datalogger`) trong vòng 10-15 phút.
- Github Actions sẽ tự động đóng gói file binary này cùng giao diện (thư mục `ui/`, `config/`, và `deploy.sh`) thành 1 file `datalogger-release-v1.0.0.tar.gz`.
- Cuối cùng, file này được đính kèm vào mục **Releases** của Repository.

### 3. Cập nhật OTA trên Edge Device (Máy Pi của Khách hàng)
Phần mềm Data Logger đang chạy tại nhà máy hoàn toàn có khả năng tự cập nhật bản thân nó thông qua mạng Internet:

1. Vào tab **Settings > General** trên ứng dụng Data Logger.
2. Nhấn nút **"Kiểm tra cập nhật (OTA)"**.
3. App (Thông qua `core/updater.py`) sẽ gọi lên GitHub API để tìm bản Release mới nhất.
4. Nếu có bản mới, nó sẽ tự bật thông báo xác nhận an toàn (`QMessageBox`).
5. Nếu người dùng **Đồng ý**, app tải file `.tar.gz` về `/tmp` và gọi `deploy.sh --ota`.
   - Dừng service `datalogger` an toàn.
   - Trích xuất dữ liệu, RSync đè file mới (cam kết bảo vệ `datalogger.db`, thư mục `config`, `logs`).
   - Tự động daemon-reload và khởi động lại.

---

## Các thao tác với `deploy.sh` dành cho System Admin

Tất cả các tính năng quản lý thiết bị đều nằm gọn trong script thần thánh báo cáo này. 

Mở Terminal trên máy Pi (hoặc chạy qua SSH) và gõ:
```bash
./deploy.sh
```

Menu Interactive sẽ hiển thị như sau:
```text
===========================================
    DATA LOGGER - DEPLOY & OTA MANAGER     
===========================================
 1. Release phiên bản mới (Git Tag -> CI/CD)
 2. Build binary Nuitka thủ công trên Pi
 3. Cài đặt SystemD service (--service)
 4. Cập nhật OTA cài File thủ công (--ota)
 5. Xem version hiện tại
 6. Thoát
===========================================
```

**Các Argument truyền thẳng (Dành cho Auto-script):**
- `./deploy.sh --service`: Thiết lập file `/etc/systemd/system/datalogger.service`, enable tự khởi động cùng OS.
- `./deploy.sh --ota /tmp/file.tar.gz`: Giải nén, thiết lập RSync loại trừ (-exclude) đè bản cập nhật Firmware, khởi động lại app.
- `./deploy.sh --version`: Xem bản `VERSION` hiện tại.

---

## Log & Maintenance

Toàn bộ log được chia ra làm 2 hệ thống rõ ràng:
1. **Application Log** (Các lỗi do phần mềm như Modbus timeout, FTP fail):
   ```bash
   tail -f var/logs/app.log
   ```
2. **SystemD Log** (Các lỗi liên quan tới hệ điều hành, crash daemon, permission):
   ```bash
   journalctl -u datalogger -f
   ```

---

## Stack công nghệ cốt lõi

| Thành phần | Công nghệ |
|---|---|
| **Core & OOP** | Python 3.12+ |
| **Giao diện (UI)** | PySide6 6.x + QML (Qt Quick Controls 2) |
| **Cơ sở dữ liệu** | SQLite 3 (Cấu hình High-Performance **WAL** Mode & Custom Cache -20000) thông qua **SQLModel** |
| **Giao thức Công nghiệp**| pymodbus 3.x (Hỗ trợ USB-RS485 RTU). Cơ chế Auto-Polling đa luồng bằng `QThread` |
| **Bảo mật** | cryptography (Fernet AES-128) để giấu mật khẩu đăng nhập, chống đọc ngược SQL |
| **Internet & Cloud** | asyncssh (sFTP) + paho-mqtt (Telemetry Gateway Skeleton) |
| **DevOps & Build**| **Nuitka standalone** biên dịch C++, đóng gói bằng **GitHub Actions** Self-hosted runner. |

*(Dự án được bảo trì nội bộ).*
