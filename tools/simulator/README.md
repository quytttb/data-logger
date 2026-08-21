# Modbus RTU Sensor Simulator (dev-only)

Giả lập cảm biến Modbus RTU để test Data Logger **không cần phần cứng cảm biến thật**.

## Cài đặt nhanh trên Raspberry Pi

```bash
# 1. Cài gói phụ thuộc
sudo apt-get update && sudo apt-get install -y socat python3-pymodbus

# 2. Copy 2 file này vào Pi
sudo mkdir -p /usr/local/lib/data-logger
sudo cp modbus_rtu_simulator.py /usr/local/lib/data-logger/
sudo cp modbus-simulator.service /etc/systemd/system/

# 3. Reload systemd và bật service
sudo systemctl daemon-reload
sudo systemctl enable --now modbus-simulator.service
```

Service sẽ tạo cặp serial ảo:
- **DataLogger dùng**: `/run/data-logger/ttyVIRT0`
- **Slave giả lập lắng nghe**: `/run/data-logger/ttyVIRT1`

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

Chỉnh file `/usr/local/lib/data-logger/modbus_rtu_simulator.py` hoặc tạo override systemd:

```bash
# Tạo file override
sudo systemctl edit modbus-simulator.service
```

Nội dung override:
```ini
[Service]
ExecStart=
ExecStart=/bin/sh -c '/usr/bin/socat pty,link=/run/data-logger/ttyVIRT0,raw,echo=0,mode=0660 pty,link=/run/data-logger/ttyVIRT1,raw,echo=0,mode=0660 & socat_pid=$!; trap "kill $socat_pid 2>/dev/null || true" EXIT; while [ ! -e /run/data-logger/ttyVIRT1 ]; do sleep 0.1; done; exec /usr/bin/python3 /usr/local/lib/data-logger/modbus_rtu_simulator.py --port /run/data-logger/ttyVIRT1 --slave-id 1 --baudrate 9600 --value 25.0 --amplitude 2.0 --period 60.0'
```

| Tham số | Mặc định | Mô tả |
|---------|----------|-------|
| `--slave-id` | `1` | Modbus slave ID |
| `--baudrate` | `9600` | Tốc độ serial |
| `--value` | `25.0` | Giá trị trung bình (°C) |
| `--amplitude` | `2.0` | Biên độ dao động (±°C) |
| `--period` | `60.0` | Chu kỳ sin (giây) |

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
sudo systemctl daemon-reload
```

## Lưu ý

- Chỉ dùng cho **phát triển/kiểm thử**, không đóng gói vào `.deb` production.
- DataLogger đọc Modbus RTU (master) → simulator là Modbus RTU **slave**.
- Nếu Pi có USB-RS485 thật: dừng simulator, cắm dây, đổi serial port trong Settings sang `/dev/ttyUSB0` (hoặc thiết bị thật).