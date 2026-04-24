# Hướng Dẫn Test Tính Năng Cảnh Báo & Digital I/O (Phase 1)

Dưới đây là hướng dẫn chi tiết từng bước để test toàn bộ tính năng Alarm & Digital I/O (DI/DO) mới được bổ sung trong Phase 1 bằng cách dùng **Converter RS485** và **Đồng hồ đo điện (VOM)** để mô phỏng.

---

## Bước 1: Chuẩn bị thiết bị và Chạy ứng dụng

1. **Kết nối phần cứng:**
   - Cắm Converter RS485 vào máy tính/Raspberry Pi.
   - Kết nối Converter RS485 với Modbus Slave (có thể là phần mềm mô phỏng Modbus Slave trên máy tính, hoặc một Relay Board thực tế có cổng RS485).
2. **Khởi chạy ứng dụng:**
   - Mở terminal và chạy ứng dụng Data Logger:
     ```bash
     python main.py
     ```

---

## Bước 2: Test Giao diện Cấu hình (Settings)

1. Mở tab **Settings** (Cài đặt) trên giao diện ứng dụng.
2. Thêm một cảm biến mới (hoặc Edit cảm biến hiện có).
3. **Cài đặt Threshold (Ngưỡng cảnh báo):**
   - Tìm ô **Min threshold** và nhập một giá trị (VD: `20`).
   - Tìm ô **Max threshold** và nhập một giá trị (VD: `80`).
   - *(Lưu ý: Nếu giá trị đọc được ≤ 20 hoặc ≥ 80, hệ thống sẽ kích hoạt Alarm).*
4. **Lưu lại** để cảm biến được ghi vào Database.
5. **Cài đặt Digital I/O:**
   - Bấm Edit lại cảm biến vừa tạo. Lúc này phần **Digital I/O** sẽ hiện ra ở dưới cùng.
   - Bấm nút **+ DO** (Thêm Digital Output).
   - Nhập thông số:
     - **Label:** `Còi Báo Động` (hoặc tên tuỳ ý).
     - **Slave ID:** ID của board Relay (VD: `2`).
     - **Address:** Địa chỉ Coil của Relay trên board (VD: `0`).
     - Bật công tắc **Trigger on Max** và **Trigger on Min** để còi kêu khi vượt cả 2 ngưỡng.
   - Bấm **Add**. Bạn sẽ thấy một dòng trạng thái màu đỏ (DO) hiện trong danh sách.
   - Đóng hộp thoại lại.

---

## Bước 3: Test Giao diện Giám sát (Monitor) & Logic Cảnh báo

1. Chuyển sang tab **Monitor** (Giám sát) trên UI.
2. Bấm nút **Start** để bắt đầu quá trình đọc (Polling) Modbus.
3. **Kịch bản 1: Giá trị Bình thường (Normal)**
   - Dùng phần mềm mô phỏng Modbus Slave (hoặc thiết bị đo thực) trả về giá trị nằm trong khoảng an toàn (VD: `50`).
   - Trên UI: Thẻ cảm biến hiển thị bình thường, đường viền màu xanh lá (OK).
4. **Kịch bản 2: Vượt ngưỡng Max (Max Alarm)**
   - Đổi giá trị Modbus Slave lên `85` (vượt Max threshold = 80).
   - Đợi 1 chu kỳ đọc (vài giây).
   - **Trên UI:** Thẻ cảm biến sẽ **đổi viền sang màu đỏ và nhấp nháy**. Xuất hiện huy hiệu chữ **"ALARM"** màu đỏ, và có dòng chữ **▲ MAX** báo hiệu vượt ngưỡng trên.
5. **Kịch bản 3: Giảm xuống dưới ngưỡng Min (Min Alarm)**
   - Đổi giá trị Modbus Slave xuống `15` (dưới Min threshold = 20).
   - Đợi 1 chu kỳ đọc.
   - **Trên UI:** Thẻ cảm biến vẫn nhấp nháy đỏ, huy hiệu ALARM, nhưng chữ sẽ đổi thành **▼ MIN**.
6. **Kịch bản 4: Hết cảnh báo (Clear Alarm)**
   - Đổi giá trị về lại vùng an toàn (VD: `50`).
   - Đợi 1 chu kỳ.
   - **Trên UI:** Thẻ cảm biến trở lại bình thường (xanh lá), mất huy hiệu ALARM.

---

## Bước 4: Test Lệnh Xuất DO bằng Đồng hồ VOM

Để chắc chắn Worker đã gửi lệnh Modbus Write Coil (`0x05` hoặc `0x0F`) xuống thiết bị RS485 khi có cảnh báo:

1. **Setup Đo kiểm:**
   - Đấu 2 que đo của đồng hồ VOM vào chân **COM** và chân **NO** (Normally Open) của Relay tương ứng với địa chỉ DO bạn đã setup ở Bước 2.
   - Vặn VOM sang thang đo **Thông mạch** (có tiếng kêu bíp) hoặc thang đo Điện trở (Ohm).
2. **Kích hoạt Alarm:**
   - Chỉnh giá trị cảm biến trên Modbus mô phỏng vượt ngưỡng Max (hoặc Min).
   - Khi UI báo ALARM nhấp nháy đỏ, đồng hồ VOM phải **kêu bíp bíp** (hoặc điện trở về 0Ω). Điều này chứng tỏ phần mềm đã gửi lệnh đóng Relay thành công.
3. **Tắt Alarm:**
   - Chỉnh giá trị cảm biến về vùng an toàn.
   - Khi UI hết ALARM, đồng hồ VOM sẽ **ngừng kêu** (điện trở vô cực). Phần mềm đã gửi lệnh ngắt Relay.

---

## Bước 5: (Tuỳ chọn) Test Digital Input (DI)

Nếu bạn có nút nhấn hoặc công tắc hành trình gắn vào Modbus DI Board:

1. Trong giao diện Edit Sensor, bấm **+ DI** thay vì DO.
2. Khai báo **Slave ID** và **Address** của cổng Input (Discrete Input).
3. Đóng tiếp điểm (nhấn nút/công tắc) trên phần cứng.
4. Hiện tại Phase 1 đã đọc trạng thái DI (`_read_di_states` trong Worker), dữ liệu này đang được gửi ngầm lên UI (payload có chứa `di_states`). Trong các Phase sau chúng ta sẽ vẽ UI để hiển thị trạng thái DI này lên thẻ cảm biến (nếu bạn muốn). Tạm thời bạn có thể xem log ở Terminal để thấy trạng thái DI được đọc về.
