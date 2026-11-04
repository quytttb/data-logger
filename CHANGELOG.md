# Changelog

## Unreleased

- Mở rộng vùng chạm các tab icon trong Settings; đưa Show DI/DO lên cùng hàng với nhãn Monitor layout.

### Tài khoản, audit và hiệu chuẩn đa điểm
- Thu gọn tab Settings thành icon; chuyển Audit vào tab con của Users. Bảng
  Users dùng Add/Edit/Delete như Sensors, màn sửa quản lý vai trò, trạng thái
  và mật khẩu; xóa tài khoản có xác nhận, RBAC và audit cùng transaction,
  bảo vệ admin cuối và giữ lịch sử audit/hiệu chuẩn.
- Bố trí hai cột cho bước tạo admin đầu tiên để thấy nút tạo tài khoản trên
  màn hình kiosk 1024×600.
- Cho phép xem Monitoring, History, Trending và bộ lọc không cần đăng nhập;
  chỉ yêu cầu xác thực khi vào Settings/Tester hoặc hiệu chuẩn. Hết phiên sau
  5 phút không che màn hình, rời Tester thì nhả cổng để giám sát tiếp tục.
- Đồng bộ phiên `AuthService` QML và backend để kiểm tra quyền dùng cùng tài khoản.
- Thêm tài khoản kiosk viewer/operator/admin, khởi tạo admin lần đầu, PBKDF2
  có salt riêng, đổi/reset mật khẩu, khóa tạm sau nhiều lần sai và tự khóa phiên.
- Thêm audit có lọc/phân trang, retention 365 ngày và ghi nguyên tử cùng thay
  đổi cấu hình/hiệu chuẩn; REST config được ghi với actor thiết bị từ xa, không
  ghi secret hay JSON nâng cao vào audit.
- Thay hai điểm riêng bằng hồi quy tuyến tính 2..N điểm; lưu phiên/điểm, xem
  sai số và R², xác nhận trước áp dụng. Giữ hệ số thủ công và JSON legacy;
  runtime tiếp tục áp dụng `a*x+b` và nạp lại khi hệ số đổi.
- Sửa transaction xóa cảm biến/cascade, không để revision lùi hoặc báo thành
  công khi cập nhật revision/token/audit thất bại; bổ sung test CTest cho RBAC,
  audit, rollback, hồi quy và REST config.
- Chưa chạy build/test trên Raspberry Pi; cần kiểm thử kiosk, ngắt điện, TT10,
  FTP và kết nối Central trước khi triển khai vận hành.

### Trending lịch sử + downsampling
- Thêm `Downsampler` min-max bucket (`src/utils`, k=400 → ~800 điểm):
  giữ envelope/đỉnh, neo điểm alarm, luôn giữ đầu/cuối (kèm test)
- Thêm `SensorDataDao::queryRangeForChart` (ASC, forward-only, trần 200k dòng)
- Thêm `TrendingHistoryViewModel` (QtConcurrent + downsample, singleton QML)
- `TrendingFilterDialog` mới (kit `Dialog`): SpinBox số 1-365 (nhập tay được)
  + ComboBox Phút/Giờ/Ngày + chọn cảm biến; nút Trực tiếp về realtime
- `TrendingView`: mode live/history, nhãn trục X theo khoảng, overlay loading
- Kit: `DateField`/`DatePickerPopup` bỏ `MouseArea` → `TapHandler`/`HoverHandler`,
  popup 320x380 → 340x400 cho kiosk touch
- Fix review: DAO báo `truncated` khi vượt 200k dòng (banner + toast),
  query mới hủy query cũ qua cancel token, `clear()` hủy worker,
  `removeSeries` kèm `destroy()`, Downsampler giữ alarm khi maxPoints<4,
  Apply disable khi loading, nối `messageSent` Trending vào Main
- Kit DatePicker: floor popup 340, tap cả icon, pressed visual, clamp overlay,
  `isToday` chỉ tháng hiện tại, `Accessible.Button` + phím Enter/Space

## 2.6.0 — 2026-09-22

### Unify bảng + touch-only
- Monitor list: bỏ custom `ListView`, dùng `AppTableView` qua `MonitorTableModel`
  bridge (4 cột Sensor/Value/Unit/Status, 2 badge co theo text); grid giữ
  `GridView`, badge `labelSmall` → `labelMedium`
- Touch-only kiosk: xóa `hoveredRow`/`HoverHandler` khỏi kit, xóa
  `onDoubleClicked` (edit chỉ qua nút Pencil), Sensors toggle + accent bar,
  bỏ hover pill sidebar
- Header/cột thẳng hàng: kit thêm `headerAlignCenter`; DIO 1:1.8, combo sensor
  wrap 2 dòng `(Slave; Addr)`; `DateField` 118 → 150; icon button đồng bộ 48px
- Nút restart nền error đậm; cột Sensor dùng font `bodyMedium` rõ ràng

### History
- Đổ kết quả theo batch 500 (`appendRows`) qua event loop, không khựng UI
- Chỉ search lần đầu / cùng bộ lọc bỏ qua; bấm lại tab hiện cache ngay

### Tên sensor + boot
- Tên đầy đủ `Symbol_Tên` cho Monitor cards/table (`sensor_symbol` vào map,
  `displayLabel` dùng `_`); DI/DO chưa gán symbol giữ tên trần
- Splash logo 4M lúc boot (overlay, tự ẩn) + lúc reboot (hiện 1s che log tắt máy)
- Cmdline `quiet/logo.nologo` ẩn log boot; dọn service thừa (tftpd/dnsmasq)

## 2.1.0 — 2026-07-03

### TT10 / Phụ lục 15 compliance
- Rename `ftpPrefix` / `serverFileSuffix` → `filePrefix` / `fileSuffix` with DB migration
- `SensorSymbols` QML singleton and `SensorSymbolCatalog.h` (Bảng 34)
- `sensor_symbol` / `sensorSymbol` replaces legacy parameter code naming
- `Tt10ReportWriter` — TAB-separated report content (5 columns per sensor)
- Filter FTP reports by `transmit_enabled` on active ANALOG sensors
- **Thông số truyền** settings sub-tab: auto-add toggle, symbol edit, LƯU / XÓA
- `ReportNaming`, per-file FTP `remote_path`, live path preview
- Unit tests (`tt10_test`) and `docs/tt10-data-format.md`

### Kiosk & platform
- Headless Pi support: bundle eglfs/KMS platform plugin and ICU in `.deb`
- On-screen Qt Virtual Keyboard (fullscreen, numeric layouts, OK enter key)
- System reboot button with polkit rule; dialout serial access
- Waveshare 1024×600 display fix; hide cursor on eglfs

### Monitor & sensors
- DO relay sync; decluttered analog cards; DI Status legend removed from task bar
- Timezone applied to OS via `timedatectl`; removed non-functional auto-sync toggle

### API & security
- REST `/api/v1/config` aligned with Contract v1 for Central Logger
- Device binding lock screen (`DeviceLock`) for unauthorized hardware
- `station_code` derived from device ID

### Other
- Utils reorganized by domain; QML singleton helper moved to `qml/` subfolder
- CI: GitHub Actions dependency upgrades

## 2.0.9 — 2026-06-22

Prior releases: see Git tags `v2.0.0` … `v2.0.9`.
