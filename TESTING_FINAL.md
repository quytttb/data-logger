# 🎯 FINAL E2E TESTING: Tích hợp Phần cứng thực tế

Chúc mừng bạn đã có đầy đủ phần cứng trong tay! Module **Ebyte ME31-AAAX4220** là một thiết bị cực kỳ lý tưởng để giả lập và test toàn bộ các tính năng của Data Logger vì nó bao gồm cả Analog Input (AI) để giả lập cảm biến, Digital Output (DO) để test báo động, và Digital Input (DI).

Dựa trên tài liệu kỹ thuật của ME31, thông số mặc định của thiết bị là: `Baudrate: 9600`, `Data bits: 8`, `Parity: None`, `Slave ID: 1`.
Dưới đây là kịch bản kiểm thử End-to-End từ đấu nối đến khi hệ thống tự động chốt Relay.

---

## BƯỚC 1: Đấu Nối & Chuẩn Bị
1. **Nguồn & Kết nối:**
   - Cấp nguồn 12V cho module ME31.
   - Dùng cáp USB-to-RS485 nối từ máy tính vào chân A/B của ME31.
2. **Setup Tín hiệu (AI):**
   - Kết nối nguồn phát dòng 4-20mA (từ đồng hồ đo/máy phát) vào chân **AI1** (cực dương +) và chân **GND** / **AGND** (cực âm -) của module.
   - ⚠️ *(Lưu ý: Bức ảnh sơ đồ tạo bởi NotebookLM bạn gửi đang hiển thị sai khi cắm vào chân AI1 và AI2. Chân AI2 là kênh tín hiệu độc lập thứ 2 chứ không phải chân mass. Bạn bắt buộc phải cắm vào AI1 và GND mới đo được nhé!)*
3. **Setup Cảnh báo (DO):**
   - Cắm 2 que của đồng hồ VOM vào chân **COM** và **DO1** (Relay 1) của ME31. Bật đồng hồ sang chế độ đo thông mạch (kêu bíp).
4. Khởi chạy phần mềm: `python main.py`

---

## BƯỚC 2: Cấu hình Giao tiếp (Settings > Connection)
1. Mở App, vào **Settings** -> **Connection**.
2. Chọn đúng cổng Port của USB (vd: `/dev/ttyUSB0` hoặc `COM3`).
3. Set **Baudrate:** `9600`, **Data bits:** `8`, **Parity:** `None`, **Stop bits:** `1`.
4. Nhấn **Save**.

---

## BƯỚC 3: Test Kết Nối bằng Modbus Tester
*Mục đích: Đảm bảo PC đọc/ghi đúng dữ liệu với module trước khi cấu hình tự động.*

1. Sang màn hình **Modbus Tester** (biểu tượng phích cắm).
2. **Đọc giá trị dòng điện (mA) từ AI1:**
   - ME31 lưu giá trị float (mA) ở địa chỉ: `200` (0x00C8).
   - Thiết lập: `Slave: 1`, `Address: 200`, `Length: 2`, `Register: Input Registers (0x04)`.
   - Data type: `float32`.
   - Nhấn **Scan**. Nếu kết quả trả về đúng số mA bạn đang cấp (vd: `4.02` mA) thì kết nối thành công! Ghi nhớ lại định dạng **Byte Order** (ABCD hay CDAB) để dùng cho bước sau.
3. **Thử kích hoạt còi/Relay thủ công (DO1):**
   - ME31 lưu trạng thái Relay 1 ở địa chỉ: `0` (0x0000).
   - Thiết lập: `Slave: 1`, `Address: 0`, `Length: 1`, `Register: Coils (0x01/0x05)`.
   - Ở cột Operations, nhập giá trị Write là `1`, bấm **Write**. 
   - Lắng nghe ME31 kêu "tạch" và đồng hồ VOM kêu bíp liên tục. Bấm Write `0` để tắt bíp.

---

## BƯỚC 4: Tạo Cảm biến & Viết Công thức
1. Sang tab **Settings** -> **Sensors** -> Bấm **[+ Add Sensor]**.
2. **Tab Basic & Modbus:**
   - Name: `Cảm biến mức nước`. Unit: `mét`.
   - Slave ID: `1`. Register Type: `Input Registers`.
   - Address: `200`. Data type: `float32`. Byte order: (Chọn cái đúng ở bước 3).
3. **Tab Scaling & Alarms:**
   - **Bật Scaling Mode**. Giả sử cảm biến có dải đo 0-10m tương ứng 4-20mA.
   - Nhập công thức: `(x - 4) * (10 / 16)` (Biến x từ mA thành mét).
   - **Bật Alarms Mode**.
   - Min Threshold: `1`. Max Threshold: `8`. 
4. Nhấn **Save**.

---

## BƯỚC 5: Cài Đặt Digital I/O (Buzzer)
1. Bấm lại vào "Cảm biến mức nước" vừa tạo trên danh sách để Edit.
2. Sang tab **Digital I/O** (nó sẽ hiện ra).
3. Form bên trái:
   - Type: `DO`. Label: `Báo động Relay 1`.
   - Slave ID: `1`. Address: `0` (địa chỉ của DO1).
   - Trigger on Max: Bật xanh. Trigger on Min: Bật xanh.
4. Bấm **ADD DO**. Bạn sẽ thấy bản ghi màu đỏ hiện bên phải. Nhấn **Save** form.

---

## BƯỚC 6: Vận hành Thực tế (Monitor)
1. Ra màn hình chính **Monitor**. Bấm nút **START**.
2. **Kiểm tra Scaling:** Thẻ cảm biến hiện lên. Nếu bạn đang cấp dòng `12mA`, UI sẽ hiển thị giá trị tính toán ra là `5.0 mét`. Viền xanh lá (OK).
3. **Test Báo động vượt ngưỡng MAX:**
   - Vặn máy phát dòng lên `19mA` (~9.37 mét).
   - Thẻ nhấp nháy ĐỎ, hiện huy hiệu **▲ MAX**.
   - **PHẦN CỨNG:** Ngay lập tức rơ-le trên ME31 đóng lại (kêu tạch), VOM **kêu Bíp Bíp** inh ỏi báo hiệu Worker đã tự động gửi lệnh kích DO.
4. **Test Hủy báo động (Clear):**
   - Vặn máy phát về `10mA` (~3.75 mét).
   - Thẻ chuyển về viền XANH, mất huy hiệu ALARM.
   - **PHẦN CỨNG:** Rơ-le nhả ra, VOM **tắt tiếng**.
5. **Test Báo động dưới ngưỡng MIN:**
   - Giảm máy phát về `4.5mA` (~0.31 mét).
   - Thẻ nhấp nháy ĐỎ, báo **▼ MIN**.
   - **PHẦN CỨNG:** VOM lại kêu bíp bíp.

---

## BƯỚC 7: Lưu trữ (History)
1. Chuyển sang màn hình **History**.
2. Xác minh các thay đổi thông số bạn vặn nãy giờ đều đã được lưu xuống bảng: Cột `Value` sẽ chứa các giá trị tính bằng mét, cột `Raw` chứa dòng điện mA đọc được.

> [!SUCCESS]
> Nếu bạn hoàn thành trót lọt từ Bước 1 đến Bước 7, nghĩa là kiến trúc lõi của chúng ta (Master -> Worker -> UI -> Database -> IO Control) đã **hoạt động xuất sắc** ngoài đời thực. Đây sẽ là minh chứng quan trọng nhất cho sự thành công của dự án! Chúc bạn test vui vẻ!
