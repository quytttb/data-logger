# Changelog

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
