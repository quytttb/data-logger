# Kế hoạch Triển khai: Hệ thống Cảnh báo (Relay) và Quản lý người dùng

Dựa theo yêu cầu mới nhất, chúng ta sẽ tập trung vào 2 tính năng chính:
1. **Hệ thống Cảnh báo (Alarm System):** Dùng Modbus RTU để điều khiển Digital Output (Relay/Còi/Đèn) khi giá trị đọc được (Analog Input) vượt ngưỡng an toàn.
2. **Quản lý người dùng:** Thêm chức năng đăng nhập, phân quyền cơ bản.
3. Các tính năng chưa làm (Modbus TCP, Web, Đa ngôn ngữ) sẽ được bỏ qua trong kế hoạch này, toàn bộ UI tạm thời sử dụng Tiếng Anh.

## Proposed Changes

### Phase 1: Kiến trúc Digital I/O (DI/DO) cho từng Cảm biến
Thay vì chỉ 1 Relay, mỗi cảm biến (Analog) sẽ được phép cấu hình tùy ý danh sách các DI (Digital Input) và DO (Digital Output) đi kèm (ví dụ từ 1 đến 5 DI/DO). 

*Lưu ý về DI: DI (Digital Input) thường dùng để đọc trạng thái (như nút nhấn bưu điện, công tắc phao, cảm biến cửa mở). Việc gán DI vào cảm biến giúp trạm có thể hiển thị trạng thái ON/OFF hoặc ghi log các sự kiện (ví dụ: Cảm biến mức nước A đi kèm với 1 phao báo cạn DI).*

#### [MODIFY] `models/sensor.py` & [NEW] `models/digital_io.py`
- Thay vì thêm trực tiếp cột vào bảng `Sensor`, tạo thêm bảng `SensorIO` (hoặc lưu dạng JSON) để mỗi cảm biến có thể gán N thiết bị DI/DO.
- **Cấu hình DO (Relay/Còi/Đèn):** Lưu `slave_id`, `address`, `trigger_type` (vượt Max thì bật, hay tụt Min thì bật).
- **Cấu hình DI (Công tắc/Trạng thái):** Lưu `slave_id`, `address`, `label` (tên hiển thị, vd: "Trạng thái phao cạn").
- Bảng `Sensor` bổ sung `min_threshold` và `max_threshold`.

#### [MODIFY] `workers/modbus_worker.py`
- **Đọc Analog & Đọc DI:** Trong vòng lặp đọc dữ liệu, worker sẽ đọc giá trị Analog của cảm biến, sau đó đọc tiếp trạng thái các DI được gán cho cảm biến đó (dùng `read_discrete_inputs` hoặc `read_coils`).
- **Xử lý Cảnh báo (Write DO):** Nếu giá trị Analog vượt ngưỡng Min/Max, worker sẽ phát lệnh Modbus `write_coil` tới các DO tương ứng được cấu hình để kích hoạt còi/đèn. Nếu giá trị về bình thường thì tắt DO.
- Đóng gói toàn bộ payload (Analog Value + DI Status + Alarm Status) gửi ra UI.

#### [MODIFY] `ui/qml/views/SettingsView.qml` & `ui/controllers/settings_controller.py`
- Cải tiến giao diện "Sensor Settings" thành dạng Master-Detail hoặc có thêm tab "Cấu hình I/O". 
- Cho phép người dùng Thêm/Sửa/Xóa các DI và DO của cảm biến đó (đúng như ý "thích thêm bao nhiêu thì thêm").

#### [MODIFY] `ui/qml/views/DashboardView.qml`
- Thẻ cảm biến (Sensor Card) sẽ có thêm 1 khu vực nhỏ hiển thị trạng thái các DI (chấm xanh/đỏ) và trạng thái báo động (Alarm).

---

### Phase 2: Quản lý người dùng & Bảo mật (User Management)

#### [NEW] `models/user.py`
- Tạo bảng `User` lưu trữ: `id`, `username`, `pin_code` (mã PIN 4-6 số cho nhanh trên màn cảm ứng) hoặc `password_hash`, `role` (Admin / Viewer).

#### [MODIFY] `core/database.py`
- Tự động tạo tài khoản Admin mặc định (ví dụ: Admin / PIN: 1234) nếu Database chưa có user nào.

#### [NEW] `ui/qml/views/LoginView.qml`
- Giao diện màn hình Khóa/Đăng nhập (sử dụng Numpad ảo để nhập PIN nhanh trên màn cảm ứng Pi).

#### [MODIFY] `ui/qml/Main.qml`
- Ẩn màn hình Settings/Cài đặt. Khi bấm vào tab Settings, pop-up Login hiện ra. Chỉ có Admin mới vào được Cài đặt.
- Viewer chỉ được xem Dashboard, Biểu đồ (History) và Test Modbus.

## Verification Plan

### Automated/Local Testing
- Dùng một phần mềm giả lập Modbus (như ModRSsim2 hoặc RMMS) trên PC để giả lập giá trị Analog.
- Tăng/giảm giá trị vượt ngưỡng và kiểm tra log xem `modbus_worker.py` có phát lệnh Write Coil chính xác ra cổng Serial hay không.
- Chạy unit test kiểm tra cơ sở dữ liệu `User` và `Sensor` mới.

### Manual Verification
- Deploy qua lệnh `bash deploy.sh --quick` lên Raspberry Pi thật.
- Kết nối một board Modbus RTU Relay 4/8 kênh vật lý.
- Khởi động lại ứng dụng hoặc build app để kiểm tra giao diện đăng nhập hoạt động đúng như thiết kế.

---

### Phase 3: Đồng bộ Properties Cấu Hình (General & Server) theo Mẫu Tham Khảo

Dựa trên file `plan/map_tham_khao`, hiện tại Tab General và Tab Server của chúng ta vẫn còn thiếu nhiều properties so với thiết bị chuẩn. Cần bổ sung các trường này vào Database (`models/app_config.py`) và Giao diện (`SettingsGeneralTab.qml`, `SettingsServerTab.qml`).

#### [MODIFY] `models/app_config.py` & `ui/controllers/settings_controller.py`
Bổ sung các trường còn thiếu vào bảng `AppConfig`:
- **General (Cài đặt chung):** `timezone` (str), `auto_sync_time` (bool), `poll_interval` (đã có), `buzzer_enable` (bool).
- **Server Config (Truyền tin):** `server_active` (bool), `server_device_type` (str), `server_name` (str), `server_send_interval` (int - phút), `server_start_time` (str), `server_base_folder` (str), `server_time_folder` (str), `server_file_suffix` (str).

#### [MODIFY] `ui/qml/views/SettingsGeneralTab.qml`
Thêm các trường giao diện (theo đúng nhóm `A. THIẾT BỊ > I. Cài đặt chung` & `II. Thời gian`):
1. **Device ID** (Đổi tên từ Station Code)
2. **Name Device** (Đổi tên từ Station Name)
3. **Múi giờ** (ComboBox: UTC+7...)
4. **Đồng bộ thời gian tự động** (Switch)
5. **Còi báo (Buzzer)** (Switch)
6. **Tần suất đọc Modbus (giây)** (SpinBox)

#### [MODIFY] `ui/qml/views/SettingsServerTab.qml`
Đổi tên tab từ "FTP Config" thành "Cấu hình Truyền tin" và bổ sung các trường:
1. **Kích hoạt** (Switch)
2. **Loại thiết bị** (ComboBox: Standard...)
3. **Tên** (TextInput)
4. **Tần suất gửi (phút)** (ComboBox: 1, 5, 10, 15...)
5. **Thời gian bắt đầu** (TimePicker / TextInput)
6. **Thư mục cơ sở** (TextInput)
7. **Thư mục thời gian** (ComboBox: yyyy/MM/dd)
8. **Hậu tố tên tệp** (ComboBox)
*(Và giữ lại các trường Host, Port, Username, Password, Đường dẫn, Tiền tố đã có, mặc định giao thức là FTP)*.

---

### Phase 4: Cải thiện Giao diện (UI/UX) phần Settings
Dựa trên việc phân tích các ảnh chụp màn hình, UI hiện tại có một số điểm cần tối ưu để đạt tiêu chuẩn "Premium Design":

1. **Vấn đề Căn lề (Label Alignment):** Các Label (Device ID, Time format...) đang dùng `Qt.AlignRight` trong `GridLayout` khiến lề trái thò thụt không đều. Khoảng cách tới ô Input bị phụ thuộc vào độ rộng cửa sổ.
2. **Vấn đề Component (Controls):** 
   - `SpinBox` (như ô Poll interval) có dấu `+` và `-` bị đẩy ra quá xa hai bên mép.
   - Các ô nhập (TextField, ComboBox) khá tối, chìm vào màu nền panel.
3. **Khoảng cách (Spacing/Padding):** Tiêu đề các nhóm (Device Information, Date & Time...) chưa nổi bật, khoảng cách các hàng hơi sát nhau.

**Hành động đề xuất (Proposed Changes):**

#### [MODIFY] `ui/qml/views/SettingsGeneralTab.qml` & `SettingsServerTab.qml` & `SettingsConnectionTab.qml`
- Định dạng lại cột Label: Chuyển sang `Qt.AlignLeft` và cố định `Layout.preferredWidth` (vd: `130px`) để các nhãn tạo thành một cột thẳng hàng tăm tắp bên trái.
- Tăng `rowSpacing` và `columnSpacing` trong GridLayout để giao diện "thở" hơn.
- Thêm margin hoặc phân cách rõ ràng hơn giữa các nhóm cài đặt.

#### [MODIFY] Khung Component chung (Nếu cần)
- Tùy chỉnh lại style của `SpinBox` (nếu có file riêng) để gom cụm nút `+` `-` lại gần giá trị ở giữa, hoặc đổi thành `AppTextField` kèm Regex số cho đồng bộ.
- Nhấn nhá thêm màu `Theme.accent` cho các viền input khi được focus.
