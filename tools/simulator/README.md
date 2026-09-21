# Modbus RTU Sensor Simulator (dev-only)

Giả lập cảm biến Modbus RTU để test Data Logger **không cần phần cứng cảm biến thật**.

## Cài đặt nhanh trên Raspberry Pi

```bash
# 1. Cài gói phụ thuộc
sudo apt-get update && sudo apt-get install -y socat python3-pymodbus

# 2. Copy 3 file này vào Pi
sudo mkdir -p /usr/local/lib/data-logger
sudo cp modbus_rtu_simulator.py /usr/local/lib/data-logger/
sudo cp modbus-simulator.sh  /usr/local/lib/data-logger/
sudo chmod +x /usr/local/lib/data-logger/modbus-simulator.sh
sudo cp modbus-simulator.service /etc/systemd/system/

# 3. Reload systemd và bật service
sudo systemctl daemon-reload
sudo systemctl enable --now modbus-simulator.service
```

Service sẽ tạo cặp serial ảo:
- **DataLogger dùng**: `/run/data-logger/ttyVIRT0`
- **Slave giả lập lắng nghe**: `/run/data-logger/ttyVIRT1`

## Tự phục hồi (auto-heal)

Wrapper `modbus-simulator.sh` xử lý dọn dẹp mỗi lần service chạy, nên
**không cần chạy lệnh thủ công** khi reboot hoặc sau khi bị kẹt:

1. Kill **socat cũ còn sót** (pattern theo đúng link pty `ttyVIRT0/ttyVIRT1`
   của service này) → tránh lỗi *"Device or resource busy"* khi app cầm pty master cũ.
2. Đồn **symlink cũ** trong `/run/data-logger` trước khi tạo cặp pty mới.
3. Đợi cả hai link tồn tại rồi mới chạy python slave (tránh race lúc boot).
4. Trap đảm bảo socat được kill cùng khi python thoát.

Nếu app vẫn báo "Connection lost/Cannot connect" do cúp/khởi động Pi, chỉ cần
đợi app **tự reconnect** (ModbusWorker có backoff tự động). Khi cần can thiệp sâu:

```bash
sudo systemctl restart modbus-simulator datalogger
```

## Cấu hình DataLogger

Vào **Settings → Connection → Serial** và đặt:

| Trường | Giá trị |
|--------|---------|
| Serial port | `/run/data-logger/ttyVIRT0` |
| Baudrate | `9600` |
| Data bits | `8` |
| Parity | `None` |
| Stop bits | `1` |

Sau đó **Settings → Sensors → Thêm cảm biến**:

| Trường | Giá trị |
|--------|---------|
| ID | `1` |
| Name | `Nhiet do gia lap` (tuỳ ý) |
| Unit | `C` |
| Sensor type | `ANALOG` |
| Slave ID | `1` |
| Register address | `0` |
| Register type | `holding` |
| Data type | `int16` |
| Data format | `AB` |
| Active | ✅ |
| Transmit enabled | ✅ (nếu muốn xuất báo cáo) |

## Tham số simulator (tùy chỉnh)

Tạo file override systemd (không đụng vào unit mặc định):

```bash
sudo systemctl edit modbus-simulator.service
```

Nội dung override (ghi đè `ExecStart` ban đầu):
```ini
[Service]
ExecStart=/usr/local/lib/data-logger/modbus-simulator.sh
Environment=SIM_VALUE=25.0 SIM_AMPLITUDE=2.0 SIM_PERIOD=60.0
```

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `SLAVE_ID` | `1` | Modbus slave ID |
| `BAUDRATE` | `9600` | Tốc độ serial |
| `SIM_VALUE` | `25.0` | Giá trị trung bình (°C) |
| `SIM_AMPLITUDE` | `10.0` | Biên độ dao động (±°C) |
| `SIM_PERIOD` | `60.0` | Chu kỳ sin (giây) |

## Kiểm tra thủ công

```bash
# Kiểm tra service
systemctl status modbus-simulator.service

# Xem log
journalctl -u modbus-simulator -f

# Test Modbus frame thủ công (cần cài python3-serial)
python3 -c "
import serial, time
p = serial.Serial('/run/data-logger/ttyVIRT0', 9600, timeout=2)
for _ in range(3):
    p.reset_input_buffer()
    p.write(bytes.fromhex('01 03 00 00 00 01 84 0A'))
    r = p.read(7)
    print(r.hex(' '), int.from_bytes(r[3:5], 'big') / 10)
    time.sleep(1)
"
```

Output mong đợi (giá trị dao động quanh 23–27):
```
01 03 02 00 e6 39 ce 23.0
01 03 02 00 e8 3b cc 23.2
01 03 02 00 ea 3d ca 23.4
```

## Gỡ bỏ

```bash
sudo systemctl disable --now modbus-simulator.service
sudo rm /etc/systemd/system/modbus-simulator.service
sudo rm /usr/local/lib/data-logger/modbus_rtu_simulator.py
sudo rm /usr/local/lib/data-logger/modbus-simulator.sh
sudo systemctl daemon-reload
```

## Lưu ý

- Chỉ dùng cho **phát triển/kiểm thử**, không đóng gói vào `.deb` production.
- DataLogger đọc Modbus RTU (master) → simulator là Modbus RTU **slave**.
- Nếu Pi có USB-RS485 thật: dừng simulator, cắm dây, đổi serial port trong Settings sang `/dev/ttyUSB0` (hoặc thiết bị thật).
