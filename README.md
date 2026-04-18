# Data Logger

Ứng dụng giám sát cảm biến công nghiệp **chỉ triển khai và chạy trên Raspberry Pi 4** (GUI cảm ứng, Modbus, SQLite).  
Máy dev dùng để chỉnh sửa source và **deploy** lên Pi — không dùng làm môi trường chạy app.  
Đọc dữ liệu qua **Modbus RTU**, lưu trữ **SQLite**, hiển thị **PySide6/QML**, xuất **CSV/TXT** và gửi tự động qua **sFTP**.

---

## Tính năng

| Module | Mô tả |
|---|---|
| **Modbus Tester** | Kiểm tra kết nối cổng serial, quét slave ID, đọc thủ công |
| **Cài đặt** | Cấu hình thông số Modbus, cảm biến, FTP server |
| **Dashboard** | Polling tự động, hiển thị realtime, áp dụng công thức `y = ax + b` |
| **Lịch sử** | Tra cứu dữ liệu theo thời gian, xuất CSV (UTF-8 BOM) |
| **Báo cáo** | Sinh file TXT theo Phụ lục 15 (TT10/2021), gửi sFTP tự động |

---

## Yêu cầu hệ thống

- **Phần cứng**: Raspberry Pi 4 (ARM64), màn hình cảm ứng 7", cổng USB-RS485
- **OS**: Raspberry Pi OS 64-bit (Bookworm trở lên)
- **Python**: 3.12+ (trên Pi, trong `.venv` do `deploy.sh` tạo)

**Môi trường chạy:** ứng dụng chỉ chạy trên Pi sau khi deploy (`deploy.sh --quick`, binary Nuitka, hoặc systemd). Không hỗ trợ chạy production trên máy dev.

---

## Cài đặt & Deploy

### Máy phát triển (chỉ công cụ deploy)

```bash
sudo apt install sshpass rsync
```

### Deploy lần đầu lên Pi (fresh install)

```bash
# Chạy từ thư mục gốc của clone (nơi có deploy.sh). Nếu clone nằm trong thư mục cha tên data-logger: PI_HOST=<IP> bash data-logger/deploy.sh --quick
PI_HOST=192.168.31.185 bash deploy.sh --quick
```

Script tự động làm tất cả:
1. Tạo thư mục trên Pi
2. Sync toàn bộ source code qua rsync
3. Tạo Python virtualenv (`.venv`)
4. Cài dependencies: PySide6, SQLModel, pymodbus, pyserial, asyncssh, cryptography
5. Tạo thư mục `var/` cho dữ liệu persistent
6. Cài shortcut menu **Data Logger** (icon `assets/app-icon.svg`) vào *System Tools*
7. Khởi động app

> **Lưu ý**: Lần đầu cài PySide6 trên ARM64 mất khoảng 5–10 phút. **Data Logger Manager** là app cũ; app mới tên **Data Logger** với logo 4M.

### Cập nhật code (các lần sau)

```bash
PI_HOST=192.168.31.185 bash deploy.sh --quick
```

Chỉ sync code và restart app — không cài lại dependencies nếu đã có.

**Venv hỏng (thiếu `pip`, `python -m pip` lỗi):** script tự phát hiện, xóa `.venv` và tạo lại + cài lại toàn bộ package trước khi chạy app.

### Gỡ cài đặt hoàn toàn (Pi)

Dừng **systemd** `datalogger`, xóa file unit, dừng mọi tiến trình Python/binary Data Logger, xóa thư mục source trên Pi (`~/data-logger/data-logger/`).

```bash
PI_HOST=192.168.31.185 bash deploy.sh --uninstall
```

Xóa luôn dữ liệu persistent (SQLite, `secret.key`, log) trong `~/data-logger/var/`:

```bash
PI_HOST=192.168.31.185 bash deploy.sh --uninstall --purge-data
```

Sau khi gỡ, cài lại bằng `bash deploy.sh --quick` như bình thường.

### Các chế độ deploy

| Lệnh | Mô tả |
|---|---|
| `bash deploy.sh --quick` | Sync + start Python source (dùng hàng ngày) |
| `bash deploy.sh` | Sync + build Nuitka binary + restart service (~15 phút) |
| `bash deploy.sh --install` | Cài systemd service (autostart khi boot) |
| `bash deploy.sh --build-only` | Chỉ build Nuitka, không restart |
| `bash deploy.sh --uninstall` | Gỡ service + tiến trình + xóa thư mục app trên Pi |
| `bash deploy.sh --uninstall --purge-data` | Thêm: xóa `var/` (DB, config, log) |

### Cấu hình Pi khác nhau

```bash
PI_HOST=192.168.1.100 PI_USER=pi PI_PASS=raspberry bash deploy.sh --quick
```

---

## Cấu trúc thư mục

```
data-logger/
├── main.py                  # Entry point
├── deploy.sh                # Script deploy lên RPi
├── pysidedeploy.spec        # Cấu hình Nuitka build
├── pyproject.toml           # Khai báo project & dependencies
├── assets/
│   └── app-icon.svg         # Logo / icon desktop & cửa sổ (4M Technologies)
│
├── core/                    # Business logic
│   ├── _version.py          # __version__ (Hatch + QGuiApplication)
│   ├── _paths.py            # Path resolution (Python & Nuitka compiled)
│   ├── database.py          # SQLite engine (WAL mode)
│   ├── modbus.py            # Modbus RTU driver
│   ├── crypto.py            # Mã hóa AES (Fernet) cho mật khẩu FTP
│   ├── txt_generator.py     # Sinh báo cáo TXT Phụ lục 15
│   └── formula.py           # Công thức y = ax + b
│
├── models/                  # SQLModel ORM
│   ├── app_config.py        # Cấu hình ứng dụng
│   ├── sensor.py            # Thông tin cảm biến
│   ├── sensor_data.py       # Dữ liệu đo lường
│   └── report_log.py        # Lịch sử gửi báo cáo
│
├── ui/                      # Giao diện PySide6
│   ├── qml/                 # QML views
│   │   ├── Main.qml         # App window + TabBar
│   │   ├── TesterView.qml   # Tab Modbus Tester
│   │   ├── SettingsView.qml # Tab Cài đặt
│   │   ├── DashboardView.qml# Tab Dashboard
│   │   └── HistoryView.qml  # Tab Lịch sử & CSV
│   ├── tester_controller.py
│   ├── settings_controller.py
│   ├── dashboard_controller.py
│   ├── history_controller.py
│   ├── report_controller.py
│   └── sensor_model.py      # QAbstractListModel cho QML
│
├── workers/                 # QThread background workers
│   ├── modbus_worker.py     # Polling Modbus định kỳ
│   ├── database_worker.py   # Batch insert vào SQLite
│   ├── ftp_worker.py        # Sinh báo cáo & upload sFTP
│   └── scan_worker.py       # Quét slave ID
│
└── scripts/
    └── datalogger.service   # systemd unit (autostart)
```

### Dữ liệu trên RPi (không bị ghi đè khi deploy)

`deploy.sh` và file `scripts/datalogger.service` đặt biến môi trường `DATALOGGER_*` trỏ tới `var/` — mọi DB, cấu hình và log runtime nằm dưới đây.

```
/home/pi/data-logger/
├── data-logger/             # Source code (rsync từ dev)
│   └── .venv/               # Python virtualenv
└── var/                     # Dữ liệu persistent
    ├── data/                # SQLite DB, CSV, báo cáo TXT
    ├── config/              # secret.key (mã hóa FTP password)
    └── logs/                # app.log
```

---

## Xem log

```bash
# Log realtime trên Pi
ssh pi@192.168.31.185 'tail -f /home/pi/data-logger/var/logs/app.log'

# Log systemd (nếu đã cài service)
ssh pi@192.168.31.185 'journalctl -u datalogger -f'
```

---

## Stack công nghệ

| Thành phần | Công nghệ |
|---|---|
| Phiên bản | Một nguồn: [`core/_version.py`](core/_version.py) (`__version__`) — đồng bộ wheel (Hatch) và `QGuiApplication.setApplicationVersion` trong `main.py` |
| GUI | PySide6 6.x + QML (Qt Quick Controls 2) |
| Database | SQLite (WAL mode) qua SQLModel + SQLAlchemy |
| Modbus | pymodbus 3.x — **chỉ Modbus RTU** (RS-485/USB). Modbus TCP **không** hỗ trợ trong phiên bản hiện tại (có thể bổ sung sau). Trong DB / Dashboard dùng tên ngắn `holding` / `input`; Modbus Tester (QML) dùng nhãn đầy đủ (*Holding Register*, …). `core.modbus.ModbusBase.read` / `write` chuẩn hoá alias nội bộ. |
| SSH/FTP | asyncssh |
| Mã hóa | cryptography (Fernet AES-128) |
| Multi-threading | QThread + Signal/Slot |
| Packaging | Nuitka standalone (qua `pyside6-deploy`) |
| Deploy | rsync + bash script |
| Autostart | systemd |

---

## Build binary (production)

Thay vì chạy Python source, có thể compile thành binary native:

```bash
# Build trên Pi (lần đầu ~15 phút, lần sau ~5 phút)
PI_HOST=192.168.31.185 bash deploy.sh

# Binary tại: /home/pi/data-logger/data-logger/dist/DataLogger.dist/DataLogger
```

---

## Cài autostart khi boot

```bash
PI_HOST=192.168.31.185 bash deploy.sh --install
```

Sau khi cài, app tự khởi động cùng Pi. Để kiểm tra:

```bash
ssh pi@192.168.31.185 'sudo systemctl status datalogger'
```
