# Data Logger

Ứng dụng giám sát cảm biến công nghiệp chạy trên **Raspberry Pi** (GUI cảm ứng, Modbus RTU, SQLite).

Đọc dữ liệu qua **Modbus RTU (RS-485)**, lưu trữ liên tục với **SQLite (WAL)**, hiển thị biểu đồ realtime qua **Qt 6.13 / QML**, và tự động kết xuất báo cáo **TXT** hoặc đồng bộ lên máy chủ bằng **FTP**.

---

## Stack công nghệ

| Thành phần | Công nghệ |
|---|---|
| **Backend** | C++20 |
| **Giao diện (UI)** | Qt 6.13 + QML (Qt Quick Controls 2 Material) |
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
- **Qt**: 6.13+ từ [Qt Online Installer](https://www.qt.io/download), hoặc Qt 6.10+ từ apt (Ubuntu 25.04+)
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

### Sử dụng Qt Online Installer (khuyến nghị — Qt 6.13)

```bash
# Đặt đường dẫn Qt kit
export QT_DIR=$HOME/Qt/6.12.1/gcc_64

./build.sh Release
```

### Build thủ công với CMake

```bash
cmake -B build-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc-15 \
  -DCMAKE_CXX_COMPILER=g++-15 \
  -DCMAKE_PREFIX_PATH=$HOME/Qt/6.12.1/gcc_64   # bỏ nếu dùng apt

cmake --build build-release --parallel $(nproc)
```

Binary đầu ra: `build-release/bin/DataLogger`

---

## Chạy

```bash
# Qt từ Online Installer cần chỉ thư viện runtime
export LD_LIBRARY_PATH=$HOME/Qt/6.12.1/gcc_64/lib:$LD_LIBRARY_PATH

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
