# Data Logger

Ứng dụng giám sát cảm biến công nghiệp **chỉ triển khai và chạy trên Raspberry Pi 4** (GUI cảm ứng, Modbus, SQLite).  
Hỗ trợ tích hợp phần cứng đọc dữ liệu qua **Modbus RTU**, lưu trữ liên tục với **SQLite (WAL)**, hiển thị biểu đồ realtime thông qua **PySide6/QML**, và tự động kết xuất **CSV/TXT** hoặc đồng bộ lên hệ thống máy chủ bằng **FTP/sFTP/MQTT**.

Đặc biệt tự hào với hệ thống **CI/CD và OTA Updater**, cho phép nâng cấp phiên bản phần mềm từ xa mà không cần thay thẻ nhớ hoặc khởi động lại bằng rsync thủ công.

---

## Modbus TCP Server (xuất dữ liệu cho hệ tập trung)

Kiến trúc:

```
Cảm biến  ──(Modbus RTU / RS-485)──▶  Data Logger (Master + TCP Slave)  ──(Modbus TCP / LAN)──▶  Central App / SCADA
```

Bật trong **Settings → Connection → Modbus TCP Server** (toggle Enable, Bind, Port, Unit ID).

**Register map v1** — Holding Registers, **Big-endian / ABCD cố định**, độc lập với `data_format` của từng cảm biến:

| Địa chỉ HR | Nội dung |
|------------|----------|
| `0` | Map version (= 1) |
| `1` | Logger status flags — bit0 polling, bit1 RTU connected, bit2 any alarm |
| `2..3` | Unix timestamp lần cập nhật cuối (uint32) |
| `4` | Sensor count đang map |
| `10 + i*8 + 0` | sensor_id (uint16) |
| `10 + i*8 + 1` | Per-sensor flags — bit0 valid, bit1 alarm, bit2 stale |
| `10 + i*8 + 2..3` | Giá trị (float32, ABCD) |
| `10 + i*8 + 4..7` | Dự phòng |

Sensor được sắp theo `id` tăng dần (chỉ ANALOG/top-level). Đổi danh sách cảm biến cần Stop/Start polling để rebuild map.

**Cổng & quyền (Linux):**

- Mặc định **5020** để tránh privileged port (<1024).
- Muốn dùng **502** chuẩn Modbus: cấp capability cho binary hoặc chạy bằng systemd với `AmbientCapabilities=CAP_NET_BIND_SERVICE`. Ví dụ thủ công:
  ```bash
  sudo setcap 'cap_net_bind_service=+ep' /path/to/python  # hoặc binary Nuitka
  ```

**An toàn:**

- Modbus TCP không mã hoá, không xác thực — chỉ mở trong **LAN tin cậy / VLAN**.
- Mặc định bind `0.0.0.0`; nếu chỉ muốn cho một interface, đặt IP cụ thể.
- Firewall LAN nên hạn chế nguồn IP được phép kết nối.

**Test nhanh từ máy khác** (cần `pymodbus` hoặc `modpoll`):

```bash
modpoll -m tcp -a 1 -p 5020 -r 0 -c 10 -t 4 <ip_logger>
```

---

## HTTP REST API (cấu hình từ xa cho Central App)

Kênh **độc lập** với Modbus TCP — chỉ dùng cho **chỉnh cấu hình** trong **LAN nội bộ nhà máy**:

```
Central App  ──(HTTP REST / JSON, LAN)──▶  Data Logger  ──(SQLite)──▶  Workers (Modbus / Reports)
```

Bật trong **Settings → Connection → Network Services → HTTP REST Server** (toggle Active, Bind, Port, Bearer token, Config revision).

**Mặc định**: port `8080`, bind `0.0.0.0`. Bearer token được sinh tự động lần đầu khi bật (xem ô "Bearer token" trong UI, có nút **Regenerate**).

### Endpoints (API v1)

| Method | Path                  | Auth     | Mục đích |
|--------|-----------------------|----------|----------|
| GET    | `/api/v1/health`      | không    | Liveness + `revision` hiện tại (Central ping rẻ) |
| GET    | `/api/v1/config`      | Bearer   | Đọc snapshot cấu hình (root + `sensors[]`) |
| POST   | `/api/v1/config`      | Bearer   | Apply cấu hình mới (optimistic concurrency) |
| GET    | `/api/v1/docs`        | không    | Swagger UI (tự sinh từ FastAPI) |
| GET    | `/api/v1/openapi.json`| không    | OpenAPI schema |

**HTTP status chuẩn**: `200` thành công, `400` validation, `401` auth, `409` revision conflict, `413` body > 1 MB, `500` lỗi server.

**Contract POST `/api/v1/config`**:

```json
{
  "api_version": 1,
  "request_id": "<uuid>",
  "expected_revision": 12,
  "config": {
    "poll_interval": 3,
    "modbus_tcp_enabled": true,
    "sensors": [ { "sensor_type": "ANALOG", "name": "pH", "slave_id": 1, "register_address": 0 } ]
  }
}
```

- **Root config**: partial update — chỉ key xuất hiện trong `config` được cập nhật.
- **`sensors[]`**: replace **toàn bộ** bảng sensor (atomic, rollback nếu lỗi).
- **`expected_revision`** phải khớp `revision` hiện tại trên edge, sai → `409`.

**Bảo mật trên LAN nhà máy:**

- Bearer token bắt buộc; so sánh constant-time. Đổi token bằng nút **Regenerate** trong UI.
- Token **không** ghi vào log; field `config_revision` xuất hiện nhưng `rest_api_token` không được trả qua `GET /api/v1/config`.
- Bind mặc định `0.0.0.0` — hạn chế IP Central bằng **firewall**:
  ```bash
  sudo ufw allow from <IP_CENTRAL> to any port 8080 proto tcp
  sudo ufw deny 8080/tcp
  ```
- Không thiết kế đi ra Internet. Nếu nhà máy yêu cầu TLS: đặt reverse proxy nội bộ (nginx/caddy) trước Uvicorn, port 8443.

**Sinh lại OpenAPI schema** (sau khi đổi Pydantic model):

```bash
python tools/dump_openapi.py
# → openapi-v1.yaml, openapi-v1.json (gốc repo)
```

**Test nhanh từ máy khác** (cần `curl`):

```bash
TOKEN="<bearer-token-từ-UI>"
curl http://<ip_logger>:8080/api/v1/health
curl -H "Authorization: Bearer $TOKEN" http://<ip_logger>:8080/api/v1/config
```

---

## Tính năng

| Module | Mô tả |
|---|---|
| **Modbus Tester** | Kiểm tra kết nối cổng serial, quét slave ID, đọc/ghi thủ công |
| **Modbus TCP Server** | Xuất dữ liệu realtime cho hệ tập trung (SCADA / Central App) qua Ethernet — logger là TCP Slave, Central là TCP Master |
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
