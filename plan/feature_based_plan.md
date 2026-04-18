# Plan Phát triển theo Module Tính năng (Feature-Based Development)

*Ngày tạo: 07/04/2026*
*Cập nhật: 08/04/2026 — M0 ✓, M1 ✓, M2 ✓. Tiếp theo: M3 Thu thập & Monitor*

> **Triết lý:** Hoàn thiện **dọc** từng tính năng (Model → Worker → UI → Test) trước khi chuyển sang tính năng tiếp theo. Mỗi Module khi "Done" nghĩa là đã chạy được end-to-end, có kiểm thử, và không cần quay lại sửa.

---

## Tổng quan Modules

| # | Module | Mô tả ngắn | Phụ thuộc |
|---|--------|-------------|-----------|
| M0 | Nền tảng (Foundation) | DB Engine, PRAGMA, Models, Crypto, Entry Point | — |
| M1 | Modbus Tester | Công cụ độc lập dò & kiểm tra register Modbus RTU tại hiện trường | M0 |
| M2 | Cấu hình Trạm & Cảm biến | Settings QML View (Trạm, FTP, Serial) + CRUD bảng Sensor dựa trên kết quả test | M0, M1 |
| M3 | Thu thập Modbus & Monitor | ModbusWorker + DatabaseWorker + Monitor QML realtime | M0, M2 |
| M4 | Lịch sử & Xuất CSV | History QML truy vấn DB + Export file | M0, M3 |
| M5 | Báo cáo TXT & Gửi sFTP | TxtGenerator + FtpWorker + ReportLog + UI trạng thái | M0, M2, M3 |

> **Workflow thực tế tại hiện trường:**
> 1. **Dò & Test (M1):** Kỹ thuật viên cắm cáp, dùng Modbus Tester tìm thông số port, baudrate, và địa chỉ thanh ghi.
> 2. **Cấu hình (M2):** Có thông số chuẩn, nhập vào phần Cài đặt Hệ thống và khai báo danh sách Cảm biến.
> 3. **Vận hành (M3):** Hệ thống tự động thu thập theo cấu hình đã lưu.

---

## M0 — Nền tảng (Foundation)

**Mục tiêu:** Đảm bảo lõi DB, Models, Crypto và Entry Point hoạt động đúng. Đây là "móng nhà" — mọi module khác đều phụ thuộc vào đây.

### Checklist

- [x] **M0.1** `core/database.py` — Engine SQLite + PRAGMA (WAL, synchronous, temp_store, cache_size)
  - Kiểm tra: Tạo DB file thành công, PRAGMA được áp dụng đúng khi connect
- [x] **M0.2** `models/*.py` — 4 bảng SQLModel: `Sensor`, `SensorData`, `AppConfig`, `ReportLog`
  - Kiểm tra: `init_db()` tạo đủ 4 bảng, INSERT/SELECT hoạt động đúng kiểu dữ liệu
- [x] **M0.3** `core/crypto.py` — Mã hóa/giải mã Fernet cho FTP password
  - Kiểm tra: Encrypt → Decrypt khớp giá trị gốc, tự sinh `secret.key` nếu chưa có
- [x] **M0.4** `core/formula.py` — Parser coefficient JSON → tính toán y = ax + b
  - Kiểm tra: Đầu vào `{"a": 0.1, "b": -5}` + raw=100 → value=5.0
- [x] **M0.5** `main.py` — Entry point: `QGuiApplication` + `QQmlApplicationEngine` + Load file `Main.qml`
  - Kiểm tra: App tải file QML lên thành công, liên kết được context của Python, log file được tạo

### Tiêu chí Done
- [x] App khởi động không lỗi, DB file tồn tại với đủ 4 bảng
- [x] Unit test cho crypto và formula pass
- [x] Log file `logs/app.log` được ghi

### Summary
- Hoàn thành M0 — Foundation trên Raspberry Pi: DB Engine, 4 Models, Crypto, Formula, Entry Point QML đều hoạt động đúng.

### Changes
- Refactor `main.py`: chuyển từ `QApplication` + `QWidgets` sang `QGuiApplication` + `QQmlApplicationEngine` theo plan mới.
- Tạo `ui/qml/Main.qml`: shell giao diện "Precision Brutalism" với sidebar 3 tab (Monitor, Lịch sử, Cài đặt), đồng hồ realtime, status bar — placeholder cho các module tiếp theo.
- Tạo `tests/test_m0_foundation.py`: test script kiểm tra M0.1 (PRAGMA WAL/synchronous/temp_store/cache_size), M0.2 (4 bảng INSERT/SELECT), M0.3 (Fernet encrypt/decrypt), M0.4 (formula linear/polynomial).
- Cài `uv` trên RPi, sync project và cài dependencies thành công.

### Verification
- `test_m0_foundation.py` chạy trên RPi: ALL M0 TESTS PASSED ✓ (PRAGMA, Models, Crypto, Formula).
- App khởi động trên RPi (`DISPLAY=:0`): QML load thành công, log file `logs/app.log` được ghi đúng 5 dòng khởi động.

---

## M1 — Modbus Tester (Công cụ Dò & Kiểm tra)

**Mục tiêu:** Cung cấp công cụ tương tác trực tiếp với thiết bị Modbus RTU để user dò tìm thông số kết nối (baudrate, parity) và kiểm tra giá trị register trước khi cấu hình. Công cụ này hoạt động độc lập, không phụ thuộc vào `AppConfig` trong DB.

### Checklist

- [x] **M1.1** `core/modbus.py` — Modbus RTU Client wrapper
  - Đóng gói `pymodbus` client: connect/disconnect/is_connected
  - Hỗ trợ 4 loại register: Holding/Input Register, Coil, Discrete Input
  - Hỗ trợ đọc nhiều data type: Decimal (INT16 signed/unsigned), Float32, Swapped Float32
- [x] **M1.2** `ui/TesterView.qml` & Hỗ trợ Python Controller
  - **QML UI (Xóa bỏ QWidget):** Giao diện to bản, thân thiện touchscreen 7 inch.
    - Khung chọn: Port (Dropdown QML), test các mức Baudrate, Parity...
    - Nút Connect dạng to bản.
    - Component hiển thị Value dạng Digital Display siêu lớn, hai nút cộng/trừ để chỉnh Address.
  - **Python Backend:** Tạo class `TesterController(QObject)` để expose các hàm `@Slot()` và `@Property` như `connect_serial`, `read_single_register` sang cho QML binding dữ liệu.
- [x] **M1.3** `workers/scan_worker.py` — Background Scan Worker (QThread)
  - Mở rộng Signal/Slot báo về `TesterController` để đẩy Event lên `TesterView.qml` (có DataModel ListView hoặc TableView QML cho kết quả báo về).
- [x] **M1.4** Status Bar hiển thị trạng thái kết nối báo bằng Popup/Indicator QML
- [x] **M1.5** Export kết quả scan ra CSV (Được export thông qua Controller - đang hoàn thiện ở M4)

### Tiêu chí Done
- [x] Tab Modbus Tester QML kết nối được thiết bị thực tế hoặc simulator cực nhạy, hiệu ứng chạm mượt.
- [x] Dò thành công một thiết bị chưa biết địa chỉ/baudrate thông qua kết nối thử
- [x] Scan và hiển thị danh sách thanh ghi
- [x] Dừng quá trình scan an toàn

### Summary
- Hoàn thành M1 — Modbus Tester trên QML: Cho phép dò/mồi thông số RS-485 bằng giao diện cảm ứng tối ưu màn hình, tích hợp Python backend gọi xuống cổng tuần tự.
- Scan chạy trên **QThread** (`ScanWorker`) không freeze UI, có thể dừng an toàn giữa chừng.

### Changes
- Tạo mới `app/ui/qml/TesterView.qml`: Thiết kế màn hình chuyên phục vụ test Modbus với layout chia đôi (Option Connect và Digital Display Value). Nút QUÉT DẢI / DỪNG QUÉT đổi trạng thái khi đang scan.
- Sửa đổi `app/ui/qml/Main.qml`: Thay thế Text thông báo thuần bằng View `TesterView`, xóa Emojis chống hiện ô vuông ở Pi.
- Tạo class `app/ui/tester_controller.py`: `TesterController(QObject)` với `@Slot` (`connect_serial`, `read_single`, `start_scan`, `stop_scan`) và `@Property` (`isConnected`, `isScanning`). Tích hợp `ScanWorker` QThread cho scan background.
- Tạo `app/workers/scan_worker.py`: `ScanWorker(QThread)` — quét dải register nền, phát Signal `progress`/`result`/`finished_scan`, hỗ trợ `stop()` an toàn.
- Sửa đổi `app/main.py`: Initialize và đăng ký `testerController` vào QML context (`rootContext().setContextProperty`).
- Sửa `app/core/modbus.py`: Thư viện lõi đọc/ghi **Modbus RTU** bằng PyModbus (TCP không triển khai; có thể bổ sung sau). Sửa bug `write()` (dùng `val` trước khi gán). Thêm `pyserial` dependency.
- Fix DeprecationWarning: chuyển toàn bộ `session.query()` → `session.exec(select(...))` chuẩn SQLModel ở 5 file (`settings_controller`, `sensor_model`, `settings_widget`, `history_widget`, `main_window`, `ftp_worker`, test).

### Verification
- Script test `tests/test_m1_modbus_tester.py` chạy trên RPi (`/dev/ttyUSB0`) qua SSH: **21/21 PASSED**.
- DONE-1: Kết nối cảm biến thực `/dev/ttyUSB0` @ 9600 thành công, đọc `Input Register[0]` trả value.
- DONE-2: Dò baudrate tự động (thử 4800 → 9600 → hit), tìm đúng baudrate=9600.
- DONE-3: Scan dải 0–9, tìm được 8 register có giá trị.
- DONE-4: `ScanWorker` chạy QThread → `stop()` → `wait(3000)` → terminated safely.
- Khi gửi tín hiệu dò tới cấu hình sai, pymodbus timeout an toàn không crash.

---

## M2 — Cấu hình Trạm & Cảm biến

**Mục tiêu:** Gộp việc cấu hình toàn hệ thống (Cổng kết nối, FTP, Thông tin trạm) và khai báo thiết bị (Sensor) vào một nơi. Người dùng dùng tham số đã test thành công từ M1 để thiết lập vĩnh viễn vào DB.

### Checklist

- [x] **M2.1** `ui/SettingsView.qml` — Form cấu hình chung và Cấu hình Serial/FTP
  - Dùng TextField/ComboBox/SpinBox chuẩn QML với kích thước thân thiện touchscreen.
  - Backend `SettingsController(QObject)` quản lý load/save dòng cấu hình `AppConfig` SQLite. FTP password encrypt bằng Fernet.
- [x] **M2.2** Bảng CRUD cảm biến Modbus
  - QML `ListView` render từ Python `SensorListModel(QAbstractListModel)` chứa Sensor từ DB.
  - Popup thêm mới / sửa cảm biến với đầy đủ trường (name, unit, slave_id, register_address, register_type, data_type, data_format, coefficient, report_index, active).
- [x] **M2.3** Nút tiện ích kết nối M1 & M2 (Nice-to-have)
  - Thêm 5 trường serial vào AppConfig (serial_port, serial_baudrate, serial_bytesize, serial_parity, serial_stopbits).
  - Nút "LƯU VÀO CẤU HÌNH" trên TesterView ghi thông số kết nối test → AppConfig qua SettingsController.
  - Section "CẤU HÌNH SERIAL" trên SettingsView cho phép chỉnh tay.
- [x] **M2.4** Load config ở tab QML Settings
  - `Component.onCompleted` gọi `settingsController.load_config()` và `sensorModel.refresh()`. Property binding tự cập nhật UI.
- [x] **M2.5** Validation
  - Python validate: trạm rỗng, poll_interval < 1, ftp_port ngoài range, sensor name/unit rỗng, slave_id ngoài 1-247, register ngoài 0-65535. Bắn Signal → Popup QML.

### Tiêu chí Done
- [x] Thấy form đầy đủ ở View Cấu hình.
- [x] Load / Save mọi cấu hình và cảm biến vào ra DB chính xác (mật khẩu FTP encrypt).
- [x] Thêm, sửa, xóa cảm biến ổn định.

### Summary
- Hoàn thành M2 — Cấu hình Trạm & Cảm biến: form cài đặt hệ thống (trạm, FTP, serial) và CRUD sensor hoàn chỉnh trên QML.
- `SettingsController` load/save AppConfig (1 dòng DB), FTP password mã hóa Fernet, validation Python trước khi save.
- `SensorListModel(QAbstractListModel)` cung cấp model chuẩn cho QML ListView; add/update/remove qua `@Slot`, có validation đầu vào.

### Changes
- Tạo mới `app/ui/settings_controller.py`: `SettingsController(QObject)` với 8 `@Property` gắn `configLoaded` signal, `@Slot load_config/save_config`, validation trạm/FTP.
- Tạo mới `app/ui/sensor_model.py`: `SensorListModel(QAbstractListModel)` với 11 role names, `@Slot add_sensor/update_sensor/remove_sensor/get_sensor/refresh`, validation name/unit/slave_id/register_address.
- Tạo mới `app/ui/qml/SettingsView.qml`: Layout 2 panel (trái: form AppConfig; phải: sensor list + popup thêm/sửa). Dark theme "Precision Brutalism" 1024x600.
- Sửa `app/main.py`: Đăng ký `settingsController` và `sensorModel` vào QML context.
- Sửa `app/ui/qml/Main.qml`: Thay placeholder "CÀI ĐẶT" bằng `SettingsView {}`.
- Fix DeprecationWarning: chuyển toàn bộ `session.query()` → `session.exec(select(...))` chuẩn SQLModel ở tất cả các file Python (loại bỏ hoàn toàn cảnh báo deprecated).

### Verification
- Script test `tests/test_m2_settings.py` chạy trên RPi qua SSH: **26/26 PASSED, 0 DeprecationWarning**.
- M2.1: load_config tạo dòng mặc định nếu chưa có; save rồi reload — 9 trường AppConfig persist đúng.
- M2.1 (FTP encrypt): password plaintext "MySecret123" → DB lưu chuỗi mã hóa (100 ký tự) → decrypt lại đúng.
- M2.2: add → count+1 → get đúng name/slaveId/registerAddress → update đổi name/slaveId/active → remove → count trở về.
- M2.5: trạm rỗng/pollInterval=0 đều bắn error message đúng; sensor name rỗng bị reject (count không tăng).
- M2.4: reload Properties có đúng type str/int, binding QML sẵn sàng.

---

## M3 — Thu thập Modbus & Monitor Realtime

**Mục tiêu:** Hệ thống tự động kết nối bằng cấu hình Serial từ M2, đọc liên tục các cảm biến active, lưu vào DB và hiển thị Monitor.

### Checklist

- [x] **M3.1** `workers/modbus_worker.py` — Vòng lặp Polling
  - Khởi tạo `ModbusSerialClient` từ thiết lập `AppConfig` (port, baudrate, bytesize, parity, stopbits).
  - Quét tuần tự các `Sensor` active. Phát `data_ready(dict)` / `modbus_error(str)` / `connection_changed(bool)`.
  - Auto-detect `slave`/`device_id` keyword cho pymodbus 3.x.
- [x] **M3.2** Xử lý dữ liệu
  - Ép kiểu int16/uint16/float32, endianness (ABCD/CDAB/BADC/DCBA). `apply_formula()` chuyển đổi y = ax + b.
- [x] **M3.3** `workers/database_worker.py` — Batch INSERT
  - Nhận data queue, gom >=10 dòng hoặc timeout 5s để insert `sensor_data` vào DB (đã có từ M0, wired qua MonitorController).
- [x] **M3.4** `ui/MonitorView.qml` — Realtime Cards
  - `GridView` QML hiển thị sensor cards (name, value, unit, status dot, last update). `MonitorModel(QAbstractListModel)` cung cấp 7 roles.
  - Nút BẮT ĐẦU / DỪNG THU THẬP, thanh trạng thái kết nối, bộ đếm ERR.
- [x] **M3.5** Kháng lỗi & Shutdown
  - Mất kết nối → status "ERR", backoff retry (1s → 2s → 4s → ... → max 30s), tự reconnect.
  - `app.aboutToQuit` → `stop_polling()` flush queue + dừng thread an toàn.

### Tiêu chí Done
- [x] Polling chạy background tự động, hiển thị QML card realtime siêu đẹp.
- [x] Rút cáp/cắm lại app tự hồi phục. Đóng GUI không treo thread.

### Summary
- Hoàn thành M2.3 + M3 — Thu thập Modbus & Monitor Realtime.
- M2.3: Thêm 5 trường serial vào AppConfig + SettingsController + SettingsView.qml. Nút "LƯU VÀO CẤU HÌNH" trên TesterView copy thông số kết nối test → cấu hình hệ thống.
- M3: MonitorController quản lý 2 QThread (ModbusWorker polling + DatabaseWorker batch insert). MonitorModel(QAbstractListModel) cung cấp realtime data cho GridView QML. Reconnect tự động với exponential backoff.

### Changes
- Sửa `app/models/app_config.py`: Thêm 5 trường serial (serial_port, serial_baudrate, serial_bytesize, serial_parity, serial_stopbits).
- Sửa `app/ui/settings_controller.py`: Thêm 5 `@Property` serial, cập nhật `save_config()` persist 5 trường, validation baudrate/bytesize/parity/stopbits.
- Sửa `app/ui/qml/SettingsView.qml`: Thêm section "CẤU HÌNH SERIAL" (Port, Baudrate, Data bits, Parity, Stop bits).
- Sửa `app/ui/qml/TesterView.qml`: Thêm nút "LƯU VÀO CẤU HÌNH" (visible khi connected) ghi serial params → settingsController → save_config().
- Viết lại `app/workers/modbus_worker.py`: Constructor nhận full serial params + poll_interval. Thay `time.sleep(0.1)` bằng `max(0.1, poll_interval - cycle_duration)`. Thêm reconnect backoff (1s/2s/4s/.../30s). Auto-detect `slave`/`device_id` keyword. Thêm `connection_changed(bool)` signal.
- Tạo mới `app/ui/monitor_controller.py`: `MonitorModel(QAbstractListModel)` 7 roles (sensorId, name, unit, value, rawValue, status, lastUpdate). `MonitorController(QObject)` quản lý start/stop polling, tạo QThread cho ModbusWorker + DatabaseWorker, nhận `data_ready` → update model + enqueue DB.
- Tạo mới `app/ui/qml/MonitorView.qml`: Top bar (start/stop, status dot, error count) + GridView sensor cards (name, value lớn, unit, status dot, last update time). Dark theme "Precision Brutalism".
- Sửa `app/main.py`: Đăng ký `monitorController` + `monitorModel` vào QML context. `app.aboutToQuit` → `stop_polling()`.
- Sửa `app/ui/qml/Main.qml`: Thay placeholder "DASHBOARD" bằng `MonitorView {}`. Bind sidebar statusLabel vào `monitorController.statusText`.

### Verification
- Script test `tests/test_m3_monitor.py` chạy trên RPi qua SSH: **38/38 PASSED, 0 DeprecationWarning, 0 lỗi**.
- M2.3: AppConfig 5 serial fields persist đúng default và update. SettingsController serialPort/serialBaudrate/... type str/int đúng. Validation reject baudrate=12345, parity="X".
- M3.1: ModbusWorker kết nối cổng /dev/ttyUSB0, polling sensor active, data_ready signal nhận được trên main thread.
- M3.3: DatabaseWorker batch insert sensor_data — verify records tăng sau 6s polling.
- M3.4: MonitorModel load_sensors → rowCount đúng, update_value → value/status/lastUpdate cập nhật, set_all_status ERR/--- broadcast toàn bộ.
- M3.5: Backoff constants (1.0/2.0/30.0) đúng. connection_changed signal có sẵn. stop_polling dừng sạch thread + trạng thái "DỪNG".

---

## M4 — Lịch sử & Xuất CSV

**Mục tiêu:** Tra cứu ngày tháng, filter data history và xuất CSV cho USB.

### Checklist
- [x] **M4.1** `ui/HistoryView.qml` — Bộ lọc thời gian (Từ ngày - Đến ngày dùng TextField dd/MM/yyyy).
  - Top bar: 2 TextField date, nút TÌM KIẾM, số dòng kết quả, nút XUẤT CSV.
- [x] **M4.2** `ui/HistoryView.qml` — `ListView` dữ liệu lazy load qua `HistoryModel(QAbstractListModel)` (hiển thị top 5000 records).
  - 5 cột: Thời gian, Cảm biến, Đơn vị, Giá trị, Giá trị thô. Delegate striped rows.
- [x] **M4.3** `HistoryController(QObject)` — Gắn logic xuất file CSV chuẩn format UTF-8 BOM.
  - `export_csv(path)` ghi CSV header tiếng Việt + data. Excel mở đúng font.
- [x] **M4.4** Truy vấn session read-only qua QThread (`SearchWorker`).
  - `search(from_date, to_date)` chạy `SearchWorker(QThread)`, JOIN sensor_data + sensor, `LIMIT 5000`, `ORDER BY recorded_at DESC`.

### Tiêu chí Done
- [x] Tìm kiếm data chính xác, xuất CSV dùng Excel đọc lỗi font = fail.
- [x] Truy vấn khoảng thời gian rỗng → Bảng trống

### Summary
- Hoàn thành M4 — Lịch sử & Xuất CSV: tra cứu sensor_data theo khoảng ngày, hiển thị bảng realtime, xuất CSV chuẩn UTF-8 BOM.
- `HistoryController` quản lý `SearchWorker(QThread)` truy vấn DB không block UI. Validation ngày tháng + kiểm tra from <= to.
- `HistoryModel(QAbstractListModel)` 5 roles cho QML ListView. `MAX_RECORDS = 5000` giới hạn kết quả.
- CSV xuất với BOM `\xef\xbb\xbf`, header tiếng Việt ("Thời gian", "Cảm biến", "Đơn vị", "Giá trị", "Giá trị thô").

### Changes
- Tạo mới `app/ui/history_controller.py`: `HistoryModel(QAbstractListModel)` 5 roles, `SearchWorker(QThread)` truy vấn sensor_data JOIN sensor, `HistoryController(QObject)` với `@Slot search/export_csv`, properties `isLoading`/`recordCount`.
- Tạo mới `app/ui/qml/HistoryView.qml`: Top bar (date fields, nút TÌM KIẾM/XUẤT CSV, record count), ListView bảng 5 cột striped delegate. Dark theme "Precision Brutalism".
- Sửa `app/main.py`: Đăng ký `historyController` + `historyModel` vào QML context.
- Sửa `app/ui/qml/Main.qml`: Thay placeholder "LỊCH SỬ" bằng `HistoryView {}`.

### Verification
- Script test `tests/test_m4_history.py` chạy trên RPi qua SSH: **28/28 PASSED, 0 DeprecationWarning, 0 lỗi**.
- M4.1: Validation ngày — invalid format → error message, from > to → error message.
- M4.2: Seed 25 records → search today → recordCount > 0, model rowCount khớp. Search empty range (2020) → recordCount == 0.
- M4.3: CSV export tạo file đúng, header tiếng Việt, UTF-8 BOM `\xef\xbb\xbf`, data lines > 1. Export empty → thông báo "Không có dữ liệu".
- M4.4: SearchWorker chạy trên QThread — isLoading True khi search bắt đầu, False khi xong. processEvents() nhận signal cross-thread.

---

## M5 — Báo cáo TXT & Gửi sFTP

**Mục tiêu:** Lấy dữ liệu 5 phút một lần để ghi file TXT chuẩn Phụ lục 15 và gửi sFTP, hỗ trợ retry.

### Checklist
- [x] **M5.1** `core/txt_generator.py` — Tạo file TXT 5 trường (Thông số, Kết quả, Đơn vị, Thời gian, Trạng thái thiết bị)
  - Format mỗi dòng: `TenCamBien,GiaTri,DonVi,ThoiGian,TrangThai`. Sorted theo recorded_at.
- [x] **M5.2** `workers/ftp_worker.py` — Lập lịch QThread 5 phút/lần gửi sFTP qua `asyncssh`
  - FtpWorker đọc AppConfig (serial/FTP), query sensor_data 5 phút gần nhất, generate_report → upload sFTP. `connect_timeout=10` tránh hang.
- [x] **M5.3** Cơ chế Pending & Retry: thất bại → lưu `status='pending'` → gửi bù chu kỳ sau
  - `_retry_pending()` query `ReportLog` status in (pending, failed) AND retry_count < MAX_RETRY (5). Mỗi cycle retry toàn bộ pending.
- [x] **M5.4** `models/report_log.py` — Ghi log trạng thái tạo file & gửi FTP
  - ReportLog: filename, status (pending/sent/failed), retry_count, error_message, created_at, sent_at. Đã tồn tại từ M0.
- [x] **M5.5** UI Indicator status bar trong Main.qml
  - Sidebar: status dot (xanh OK / đỏ FAIL / xám tắt) + text "FTP" + pending count. Bind `reportController.isRunning/lastStatus/pendingCount`.
- [x] **M5.6** Đọc FTP password từ AppConfig, giải mã.
  - `decrypt(config.ftp_password)` trong `_generate_and_send()` và `_retry_pending()`. Đã có từ M0.

### Tiêu chí Done
- [x] File trên server sFTP chuẩn Phụ lục 15.
- [x] Ngắt mạng rồi ghi log pending. Mở mạng lại hệ thống tự gửi file pending.

### Summary
- Hoàn thành M5 — Báo cáo TXT & Gửi sFTP.
- Refactor `txt_generator.py`: format 5 trường mỗi dòng (Thông số, Kết quả, Đơn vị, Thời gian, Trạng thái thiết bị) thay vì matrix format cũ.
- `ReportController(QObject)` quản lý FtpWorker trên QThread — start/stop, expose isRunning/lastStatus/pendingCount cho QML sidebar indicator.
- FtpWorker sinh file TXT 5 phút/lần, upload qua asyncssh (connect_timeout=10s), retry pending files (MAX_RETRY=5).
- Cơ chế resilient: upload fail → ReportLog status="pending" → retry chu kỳ sau. Ngắt mạng → log pending, mở mạng → auto retry.

### Changes
- Viết lại `app/core/txt_generator.py`: Format 5 trường mỗi dòng (name, value, unit, timestamp, status). `sensor_order` dict thêm key `unit`.
- Sửa `app/workers/ftp_worker.py`: Truyền `unit` trong `sensor_order` cho `generate_report`. Thêm `connect_timeout=10` vào `asyncssh.connect()`.
- Tạo mới `app/ui/report_controller.py`: `ReportController(QObject)` — start/stop FtpWorker trên QThread. Properties: `isRunning`, `lastStatus`, `pendingCount`. Signal: `messageSent(str,str)`.
- Sửa `app/main.py`: Đăng ký `reportController` vào QML context. `app.aboutToQuit` → `stop_reporting()`.
- Sửa `app/ui/qml/Main.qml`: Thêm FTP status indicator ở sidebar — status dot + text "FTP" + pending count.

### Verification
- Script test `tests/test_m5_report.py` chạy trên RPi qua SSH: **37/37 PASSED, 0 DeprecationWarning, 0 lỗi**.
- M5.1: TxtGenerator tạo file đúng format 5 trường, 3 dòng data (2 sensor × 2 timestamps), sorted by recorded_at.
- M5.2: FtpWorker interval=5, signals ftp_status/worker_stopped, upload fail nhanh với localhost:2222 → status "FAIL".
- M5.3: ReportLog status="pending" khi upload fail, retry_count tăng, query pending/failed trả về đúng.
- M5.4: ReportLog CRUD — create/update/query status đúng, retry_count tăng sau mỗi lần fail.
- M5.5: ReportController lifecycle — isRunning toggle đúng, lastStatus cập nhật, pendingCount refresh.
- M5.6: Crypto encrypt/decrypt roundtrip OK.

---

## Thứ tự Thực hiện & Ước lượng

```
M0 (Foundation)          ██████░░░░░░░░░░░░░░░░░░  ~1.0 ngày
  ↓
M1 (Modbus Tester)       ░░░░░░███████░░░░░░░░░░░  ~1.5 ngày
  ↓
M2 (Cấu hình)            ░░░░░░░░░░░░░██████░░░░░  ~1.0 ngày
  ↓
M3 (Modbus + Monitor)  ░░░░░░░░░░░░░░░░░░░████████  ~2.0 ngày
  ↓
M4 (Lịch sử + CSV)       ░░░░░░░░░░░░░░░░░░░░░░░░██  ~0.5 ngày
  ↓
M5 (Báo cáo + sFTP)      ░░░░░░░░░░░░░░░░░░░░░░░░██  ~1.5 ngày
                                                 ──────
                                           Tổng: ~7.5 ngày
```

### Quy tắc vàng
1. **Không nhảy module** — Hoàn thành M(n) mới bắt đầu M(n+1).
2. **Luôn đóng vai QML Views** — Tách biệt logic Python (`QObject`, `@Slot`, `@Property`) và QML (`.qml`) một cách quy chuẩn.
3. **Tester trước, Config sau (M1 → M2)** — Thiết kế UI sao cho flow dùng tool test mượt mà với phần nhập cấu hình (có thể truyền tham số từ M1 -> M2).
