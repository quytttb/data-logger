# Hướng dẫn kiểm thử Phase 2: Tái cấu trúc Cấu hình & Tester

Sau khi hoàn thành Phase 2, cấu trúc giao diện đã được thay đổi đáng kể: **SettingsView** giờ được chia làm 4 tab rõ ràng, form thêm/sửa cảm biến được module hoá, **Modbus Tester** kết nối đồng bộ với cấu hình Modbus Master chung, và Backend hỗ trợ đọc các kiểu dữ liệu 32-bit.

Vui lòng làm theo các bước dưới đây để xác nhận Phase 2 hoạt động hoàn hảo.

---

## 1. Kiểm tra 4 Tab Cấu hình (Settings)

1. Mở ứng dụng, vào màn hình **Settings** (biểu tượng bánh răng).
2. Quan sát thanh TaskBar bên trái, xác nhận có 4 tab riêng biệt:
   - **General**
   - **Connection**
   - **Server**
   - **Sensors**
3. Bấm vào từng Tab và kiểm tra nội dung hiển thị có khớp và đầy đủ không. Thử nhập một vài giá trị (ví dụ: đổi Station Name ở Tab General) và lưu lại xem giá trị có được lưu xuống file DB không.

## 2. Kiểm tra Form Add/Edit Sensor (SensorConfigForm)

1. Chuyển sang Tab **Sensors**, click vào nút **[+ Add Sensor]** (hoặc double-click vào một cảm biến có sẵn để sửa).
2. Kiểm tra trường **Unit** (Đơn vị):
   - Nhấn vào ComboBox, bạn sẽ thấy danh sách 30 đơn vị phổ biến (như `°C`, `m³/h`, `mg/L`, `pH`,...).
   - Thử nhập tay một đơn vị không có trong danh sách (vd: `my_unit`) — ComboBox sẽ cho phép nhập.
3. Kiểm tra trường **Data type**:
   - Mở dropdown, xác nhận có thêm **int32** và **uint32**.
4. Chọn một cảm biến có sẵn và sửa Data type thành `int32`, Format `CDAB`, nhấn **Save** và xem thay đổi có hiển thị đúng trên danh sách không.

## 3. Kiểm tra Modbus Tester đã đồng bộ

1. Chuyển sang màn hình **Modbus Tester** (biểu tượng phích cắm).
2. Quan sát phần **Operations**:
   - Xác nhận Tab "Connection" cũ đã biến mất.
   - Thay vào đó, có một **Banner thông tin (Info banner)** hiển thị cấu hình Serial port hiện tại (được lấy trực tiếp từ thiết lập chung Modbus Master ở Settings).
   - Kiểm tra xem ô nhập **Slave ID** đã xuất hiện trong danh mục Operations chưa.
3. Nhấn **Scan** (cần cắm thiết bị hoặc mô phỏng qua socat như bạn đang chạy):
   - Tester sẽ sử dụng đúng Port/Baudrate bạn đã cài ở Settings.
   - Thay đổi Data type thành `int32` và thử Scan một thanh ghi 32-bit, đảm bảo kết quả giải mã (decode) hiển thị đúng số nguyên 32-bit.

## 4. Kiểm tra Backend (Cảm biến chạy ngầm)

1. Để ứng dụng chạy ở màn hình **Monitor** (màn hình chính).
2. Thiết lập một cảm biến ảo đọc dữ liệu 32-bit từ Modbus Simulator (qua cổng `/dev/pts/...`).
   - Data type: `uint32`
   - Endian format: Thử luân phiên `ABCD`, `CDAB`
3. Đợi vài giây để `scan_worker` chạy ngầm.
4. Kiểm tra giá trị hiển thị trên màn hình Monitor xem backend đã decode chính xác thanh ghi 32-bit chưa.

---
> [!NOTE]
> Mọi thay đổi trong cấu trúc QML đã được kiểm thử ngầm (app khởi động thành công). Vui lòng xác nhận luồng thao tác thực tế xem có vấn đề UX/UI nào không (ví dụ layout bị xô lệch, lỗi khoảng cách...). Nếu mọi thứ ổn, chúng ta có thể đóng Phase 2!
