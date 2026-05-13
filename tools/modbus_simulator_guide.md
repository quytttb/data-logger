# Hướng dẫn sử dụng Bộ Giả lập Modbus RTU (Modbus Simulator)

File `modbus_simulator.py` là một công cụ giả lập thiết bị Modbus RTU thuần (dùng thư viện `serial` chạy ở mức vật lý), tích hợp tính năng tạo giao diện điều khiển bằng PySide6. Công cụ này cho phép bạn tạo dữ liệu giả lập để kiểm tra tính năng đọc dữ liệu qua RS485 của Datalogger mà không cần thiết bị thật.

Dưới đây là lộ trình để giả lập thành công trên Linux thông qua các "cổng nối tiếp ảo" (Virtual Serial Ports).

---

## BƯỚC 1: Tạo ra 2 đầu cổng USB/COM ảo thông nhau

Terminal Linux không có sẵn cổng COM, ta sẽ dùng công cụ `socat` để tạo ra "một sợi dây cáp ảo" có hai đầu cắm. Dữ liệu gửi vào đầu này sẽ xuất hiện ở đầu kia.

Mở **một Tab Terminal MỚI** và giữ nó chạy (đừng tắt):

```bash
socat -d -d pty,raw,echo=0 pty,raw,echo=0
```

**Lưu ý:** Terminal này sẽ hiển thị tên của 2 cổng được tạo ra, ví dụ:
- `PTY is /dev/pts/1`
- `PTY is /dev/pts/2`

👉 **Nhớ kỹ 2 tên cổng này!** (Trong các ví dụ dưới đây, chúng ta sẽ gọi là cổng 1 và cổng 2).

---

## BƯỚC 2: Chạy bộ Giả lập (Simulator)

Giữ Tab Terminal ở Bước 1 luôn chạy. Mở một Terminal khác, kích hoạt môi trường ảo (`venv`) và chạy file Simulator:

```bash
source .venv/bin/activate
python3 tools/modbus_simulator.py
```

Khi giao diện Giả lập hiện lên:
1. Ở phần **Port**, điền vào hoặc chọn cổng đầu tiên (VD: `/dev/pts/1`).
2. Bấm **Start Simulator**.

Lúc này, simulator sẽ đóng vai một cảm biến chuẩn RTU đang đợi ứng dụng chính truy vấn dữ liệu.

---

## BƯỚC 3: Chạy App Data Logger và Cấu hình Kết nối

Mở ứng dụng chính trong một Terminal khác:

```bash
source .venv/bin/activate
QT_QPA_PLATFORM=xcb python main.py
```

Trong giao diện Data Logger, thực hiện các bước sau:

1. Chuyển sang Tab **Settings** -> **Connection**.
2. **Serial Port**: Nhập tên cổng thứ hai từ lệnh `socat` (VD: `/dev/pts/2`).
3. Nhấn **Save Config**.
4. Chuyển sang Tab **Tester** để kiểm tra nhanh:
   - **Baudrate**: `9600` (Simulator được thiết lập cố định ở tốc độ này).
   - **Slave ID**: `1`.

---

## Cấu hình chi tiết Sensor (Settings -> Sensors)

Khi bạn vào tab **Settings -> Sensors** và bấm **"+ Add"**, bạn cần khai báo các thông số khớp chính xác với bộ `modbus_simulator.py`. Dưới đây là các mẫu cấu hình:

### Mẫu 1: Đọc Nhiệt Độ (Temperature)
- **Name:** `Nhiệt độ phòng`
- **Unit:** `°C`
- **Slave ID:** `1`
- **Register Address:** `200`
- **Register Type:** `Input Registers`
- **Data Type:** `float32`
- **Endian Format:** `ABCD`

### Mẫu 2: Đọc Độ Ẩm (Humidity)
- **Name:** `Độ ẩm phòng`
- **Unit:** `%RH`
- **Slave ID:** `1`
- **Register Address:** `202`
- **Register Type:** `Input Registers`
- **Data Type:** `float32`
- **Endian Format:** `ABCD`

### Mẫu 3: Đọc Trạng thái lỗi (Discrete Inputs - DI)
Simulator giả lập 2 chân báo lỗi: DI 10 (Lỗi) và DI 11 (Bảo trì). Để cấu hình:
1. **Edit** cảm biến Nhiệt độ hoặc Độ ẩm đã tạo.
2. Chuyển sang tab **Digital I/O** và nhấn **Add**.
- **I/O Type:** `DI` (Digital Input)
- **Label / Name:** `Lỗi Sensor` (hoặc `Bảo trì`)
- **Slave ID:** `1`
- **Register Addr:** `10` (hoặc `11`)

### Mẫu 4: Điều khiển Còi/Đèn/Relay (Coils - DO)
Simulator giả lập 2 bóng đèn: Coil 0 và Coil 1. Khi lệnh `Write Coil` được thực hiện, bóng đèn trên giao diện Simulator sẽ sáng đỏ (`🔴`).
Cấu hình trong tab **Digital I/O** của một sensor bất kỳ:
- **I/O Type:** `DO` (Digital Output)
- **Label:** `Còi báo động`
- **Slave ID:** `1`
- **Register Addr:** `0` (hoặc `1`)

*(Khi cảm biến vượt ngưỡng Alarm, Datalogger sẽ tự động gửi lệnh Write Coil, bạn sẽ thấy đèn trên Simulator nhấp nháy đỏ).*

---

## Tóm tắt trình tự kiểm tra
1. **Bật Simulator**: Chọn cổng `/dev/pts/1`, nhập nhiệt độ `35`, nhấn **Start**.
2. **Cấu hình App**: Settings -> Connection -> Chọn cổng `/dev/pts/2` -> Save.
3. **Thêm Sensor**: Thêm sensor theo **Mẫu 1** (Nhiệt độ, Reg 200, float32, ABCD).
4. **Kiểm tra**: Chuyển qua tab **Monitor** hoặc **Tester**, con số `35` sẽ hiển thị ngay lập tức!
