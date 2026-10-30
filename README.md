# Data Logger

Ứng dụng giám sát cảm biến công nghiệp chạy trên **Raspberry Pi** (GUI cảm ứng, Modbus RTU, SQLite).

Đọc dữ liệu qua **Modbus RTU (RS-485)**, lưu trữ liên tục với **SQLite (WAL)**, hiển thị biểu đồ realtime qua **Qt 6.11 / QML**, và tự động kết xuất báo cáo **TXT** hoặc đồng bộ lên máy chủ bằng **FTP**.

---

## Stack công nghệ

| Thành phần | Công nghệ |
|---|---|
| **Backend** | C++20 |
| **Giao diện (UI)** | Qt 6.11 + QML (Qt Quick Controls 2 Material) |
| **Cơ sở dữ liệu** | SQLite 3 (WAL) — `QSqlDatabase` |
| **Giao thức công nghiệp** | Modbus RTU — `QModbusRtuSerialClient`; Modbus TCP Server — `QModbusTcpServer` |
| **REST API** | `QHttpServer` (Qt HTTP Server) |
| **Build** | CMake 3.16+ với `qt_standard_project_setup` / `qt_add_qml_module` |
| **CI/CD** | GitHub Actions — build C++ + Qt apt on `ubuntu-latest` |

---

## Cấu trúc project

```
src/
├── app/           # Entry point + QML shell (Main.qml, views/)
├── components/    # QML tái sử dụng (shell/, layout/, sensor/)
├── core/          # Controllers + QML models
├── data/          # SQLite, models, repositories
├── network/       # Modbus RTU/TCP, REST API, workers
├── theme/         # Theme singleton (Material 3)
└── utils/         # AppPaths, Crypto, Formula, …
resources/         # Icons, app icon
```

Build layers (CMake): `utils → data → network → core → theme → components → app`

---

- **Phần cứng**: Raspberry Pi (ARM64), màn hình cảm ứng 7", USB-RS485 Dongle.
- **OS**: Raspberry Pi OS 64-bit (Bookworm trở lên)
- **Qt**: 6.11+ từ [Qt Online Installer](https://www.qt.io/download), hoặc Qt 6.10+ từ apt (Ubuntu 25.04+)
- **Compiler**: GCC 15+ (`g++-15`)

---

## Build

### Cài dependencies (Ubuntu / Raspberry Pi OS Bookworm)

```bash
sudo apt-get install -y \
  cmake g++-15 \
  qt6-base-dev qt6-declarative-dev qt6-quickcontrols2-dev \
  qt6-serialbus-dev qt6-serialport-dev \
  qt6-httpserver-dev qt6-websockets-dev \
  qt6-graphs-dev qt6-quick3d-dev
```

### Sử dụng Qt Online Installer (khuyến nghị — Qt 6.11)

```bash
# Đặt đường dẫn Qt kit
export QT_DIR=$HOME/Qt/6.11.1/gcc_64

./build.sh Release
```

### Build thủ công với CMake

```bash
cmake -B build-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc-15 \
  -DCMAKE_CXX_COMPILER=g++-15 \
  -DCMAKE_PREFIX_PATH=$HOME/Qt/6.11.1/gcc_64   # bỏ nếu dùng apt

cmake --build build-release --parallel $(nproc)
```

Binary đầu ra: `build-release/bin/DataLogger`

---

## Chạy

```bash
# Qt từ Online Installer cần chỉ thư viện runtime
export LD_LIBRARY_PATH=$HOME/Qt/6.11.1/gcc_64/lib:$LD_LIBRARY_PATH

./build-release/bin/DataLogger
```

Nếu build với Qt từ apt thì không cần `LD_LIBRARY_PATH`.

---

## Modbus TCP Server

Xuất dữ liệu realtime cho hệ tập trung (SCADA / Central App):

```
Cảm biến ──(Modbus RTU / RS-485)──▶ Data Logger (Master + TCP Slave) ──(Modbus TCP / LAN)──▶ Central App
```

Bật trong **Settings → Connection → Modbus TCP Server** (Enable, Bind, Port, Unit ID).

**Register map v1** — Holding Registers, Big-endian ABCD:

| Địa chỉ HR | Nội dung |
|------------|----------|
| `0` | Map version (= 1) |
| `1` | Logger status flags — bit0 polling, bit1 RTU connected, bit2 any alarm |
| `2..3` | Unix timestamp lần cập nhật cuối (uint32) |
| `4` | Sensor count đang map |
| `10 + i*8 + 0` | sensor_id (uint16) |
| `10 + i*8 + 1` | Per-sensor flags — bit0 valid, bit1 alarm, bit2 stale |
| `10 + i*8 + 2..3` | Giá trị (float32, ABCD) |

**Cổng mặc định**: `5020`. Để dùng cổng 502 chuẩn Modbus:

```bash
sudo setcap 'cap_net_bind_service=+ep' build-release/DataLogger
```

Test từ máy khác:

```bash
modpoll -m tcp -a 1 -p 5020 -r 0 -c 10 -t 4 <ip_logger>
```

---

## HTTP REST API

Bật trong **Settings → Connection → HTTP REST Server**.

| Method | Path | Auth | Mục đích |
|--------|------|------|----------|
| GET | `/api/v1/readings` | Bearer | Snapshot giá trị cảm biến hiện tại |
| GET | `/api/v1/config` | Bearer | Đọc cấu hình (gồm cả cấu hình từng cảm biến) |
| POST | `/api/v1/config` | Bearer | Cập nhật cấu hình từ xa (chỉ các trường app-config) |
| GET | `/api/v1/health` | **None** | Kiểm tra sức khỏe hệ thống (version, uptime, modbus, crypto) |

**Rate limit**: 10 yêu cầu/giây per IP → `429 Too Many Requests` (không khóa IP).

Test nhanh:

```bash
TOKEN="<bearer-token-từ-UI>"
curl http://<ip_logger>:8080/api/v1/readings -H "Authorization: Bearer $TOKEN"
```

### `GET /api/v1/config` — response

data-logger (edge) là **Source of Truth** cho cấu hình cảm biến. Mảng `sensors[]`
được Central App đọc **read-only** (ví dụ `decimals` — số chữ số thập phân hiển thị).
`POST /api/v1/config` **không** ghi các trường cảm biến (decimals sửa tại edge).

```json
{
  "station_code": "DL-001",
  "station_name": "Data Logger",
  "poll_interval": 3,
  "serial_port": "/dev/ttyUSB0",
  "serial_baudrate": 9600,
  "config_revision": 12,
  "sensors": [
    {
      "id": 1,
      "name": "Nhiệt độ",
      "unit": "°C",
      "sensor_type": "ANALOG",
      "decimals": 2,
      "report_index": 0,
      "slave_id": 1,
      "register_address": 0
    }
  ]
}
```

Khóa join với dữ liệu Modbus của edge:

- **ANALOG**: `sensors[].id` **==** `sensor_id` trên wire FC03 (cùng là primary key DB). Central
  gắn live value + `decimals` + history theo khóa này.
- **DI/DO**: map theo **bit index** của FC02/FC01, bằng `sensors[].register_address`.
  (`decimals` không áp dụng cho DI/DO — hiển thị ON/OFF.)

> `config_revision` tăng mỗi khi cấu hình thay đổi — **bao gồm cả thêm/sửa/xóa cảm biến**
> (đổi `decimals`, threshold, scaling...) — để Central có thể phát hiện drift nếu cần.

---

## Tính năng

| Module | Mô tả |
|---|---|
| **Modbus Tester** | Kiểm tra cổng serial, quét slave ID, đọc/ghi thủ công |
| **Modbus TCP Server** | Xuất dữ liệu realtime cho SCADA / Central App qua LAN |
| **Monitor** | Polling tự động, hiển thị giá trị realtime, trending chart (Qt Graphs) |
| **Lịch sử** | Tra cứu dữ liệu quá khứ theo dải thời gian |
| **Báo cáo** | Sinh file báo cáo TXT và gửi định kỳ qua FTP |
| **Settings** | Cấu hình trạm, Modbus, cảm biến, FTP, REST API |
| **Bảo mật** | Mật khẩu mã hóa AES lưu trong SQLite; **crypto degraded flag** cảnh báo khi fallback |
| **Health & Rate-limit** | `GET /api/v1/health` (no auth), **rate-limit 10 req/s per IP** |

---

## Tài khoản kiosk, audit và hiệu chuẩn

### Đăng nhập và quyền

- Lần đầu với DB chưa có tài khoản, màn hình yêu cầu tạo **admin**; không có
  mật khẩu mặc định. Đây là màn đăng nhập kiosk, tách biệt màn khóa thiết bị
  theo license. Sau khởi động lại phải đăng nhập lại; polling nền vẫn tự chạy.
- **Viewer** xem dữ liệu; **operator** xem, dùng Modbus Tester và hiệu chuẩn;
  **admin** có thêm quyền cấu hình cảm biến/hệ thống, quản lý tài khoản và xem
  audit. Quyền áp dụng ở backend, không chỉ ẩn nút.
- Admin quản lý tài khoản tại **Settings → Users**; có thể tạo, đổi vai trò,
  tắt/bật và đặt lại mật khẩu. Tài khoản mới hoặc vừa reset phải tự đổi mật
  khẩu khi đăng nhập. Không thể tự tắt/giáng quyền tài khoản đang dùng hoặc
  vô hiệu hóa admin cuối cùng.
- Mật khẩu 8–128 ký tự, có ít nhất một chữ và một chữ số, khác username; lưu
  bằng PBKDF2-HMAC-SHA256, 600.000 vòng và salt riêng, không lưu plaintext.
  Sau 5 lần sai liên tiếp tài khoản tạm khóa 60 giây; các đợt sai tiếp theo
  tăng dần, tối đa 15 phút. Kiosk tự khóa sau 5 phút không thao tác.
- Không có cơ chế khôi phục admin qua mạng. Với thiết bị thử nghiệm, việc tạo
  lại DB là thao tác **mất toàn bộ dữ liệu và cấu hình**; chỉ làm khi đã được
  cho phép. Với thiết bị vận hành cần quy trình khôi phục riêng được phê duyệt.

### Audit

- **Settings → Audit** chỉ dành cho admin, có bộ lọc và phân trang; log gồm
  đăng nhập, quản lý tài khoản, cấu hình và áp dụng hiệu chuẩn. Ghi cấu hình từ
  REST dùng actor `remote_device` và địa chỉ nguồn, **không** giả làm người dùng
  kiosk. Bearer token vẫn là credential thiết bị như contract v1.
- Audit chỉ ghi các trường được chọn, không ghi mật khẩu, hash, REST token,
  mật khẩu FTP, JSON hệ số nâng cao hoặc ghi chú hiệu chuẩn tự do. Thay đổi
  cấu hình/hiệu chuẩn và audit liên quan được commit cùng transaction; lỗi ghi
  audit làm rollback thao tác. Các sự kiện độc lập như đăng nhập/đăng xuất được
  ghi best-effort và cảnh báo nếu DB không sẵn sàng.
- Retention audit là **365 ngày**, dọn định kỳ; chưa có chức năng export hay
  endpoint REST audit. Log không bất biến/chống sửa tuyệt đối: người có quyền
  hệ điều hành và truy cập DB vẫn có thể thay đổi nó.

### Hiệu chuẩn đa điểm

1. Đăng nhập operator/admin, mở **Monitor** và bấm **Calibrate** trên thẻ
   analog hoặc nút bút chì trong chế độ danh sách.
2. Nhập ít nhất hai cặp giá trị thô và giá trị chuẩn; thêm/xóa điểm tùy nhu
   cầu. Kiểm tra hệ số `a`, `b`, R² và sai số từng điểm, thêm ghi chú nếu cần,
   rồi xác nhận **Apply calibration**. R² chỉ thể hiện độ khớp, **không phải
   chứng nhận đạt chuẩn**.
3. Phiên và điểm được lưu để tra cứu. Lịch sử chỉ được nạp lại khi người dùng
   chọn; một phiên cũ có thể không còn tương ứng hệ số hiện hành nếu admin đã
   sửa thủ công. Hệ số đang áp dụng được lưu dạng `{"a":...,"b":...}`; khi
   monitoring đang chạy, polling được khởi động lại để nạp hệ số mới.

Admin vẫn có thể nhập `a`, `b` thủ công tại **Settings → Sensors → Scaling &
Alarms**, hoặc chỉnh JSON nâng cao. Hệ số cũ không tự sinh điểm hiệu chuẩn;
JSON chưa hiểu rõ, kể cả `coeffs` legacy, được giữ ở chế độ Advanced. Việc xóa
cảm biến cũng xóa lịch sử hiệu chuẩn của cảm biến đó theo khóa ngoại.

### Kiểm thử trên Raspberry Pi

Các test mới được đăng ký với CTest (`password_hasher_test`, `auth_data_test`,
`auth_service_test`, `audit_test`, `calibration_dao_test`, `calibration_test`,
`sensor_form_test`, `rest_config_test`). Trên Pi có bộ công cụ Qt 6.11 phù hợp:

```bash
cmake --build build-release --target password_hasher_test auth_data_test auth_service_test audit_test calibration_dao_test calibration_test sensor_form_test rest_config_test monitor_table_model_test tt10_test
cd build-release
QT_QPA_PLATFORM=offscreen ctest --output-on-failure -R '^(password_hasher_test|auth_data_test|auth_service_test|audit_test|calibration_dao_test|calibration_test|sensor_form_test|rest_config_test|monitor_table_model_test|tt10_test)$'
```

Trước khi đưa vào vận hành cần kiểm tra trên chính Pi/màn hình: tốc độ đăng
nhập, khóa/mở phiên, hiệu chuẩn khi đang polling, khởi động lại và mất điện giữa
lần ghi; sau đó kiểm tra lại TT10/FTP và kết nối Central qua REST/QR/Modbus.
Không coi kiểm tra cú pháp trên máy phát triển là thay thế các thử nghiệm này.

---

## Log

```bash
# Application log
tail -f logs/app.log

# SystemD (khi chạy dưới service)
journalctl -u datalogger -f
```

---

## CI/CD

Tag `v*.*.*` → GitHub Actions trigger `release-build.yml`:
1. Self-hosted runner (ARM64) cài Qt 6 từ apt
2. Build C++ bằng CMake
3. Đóng gói `DataLogger` + `config/` + `resources/` → `datalogger-release-vX.Y.Z.tar.gz`
4. Đính kèm vào GitHub Releases

*(Dự án được bảo trì nội bộ.)*
