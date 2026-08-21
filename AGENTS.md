# Agent instructions — Data Logger (Edge)

## Context

Ứng dụng giám sát cảm biến công nghiệp chạy trên **Raspberry Pi (ARM64, kiosk)**: đọc cảm biến qua **Modbus RTU (RS-485)**, lưu **SQLite (WAL)**, GUI cảm ứng **Qt 6.13 + QML**, xuất báo cáo **TXT** theo **Thông tư 10/2021 — Phụ lục 15 (TT10)** và đồng bộ **FTP**. Edge cũng là **Modbus TCP Server** + **REST API** để Central Logger kết nối.

- Ngôn ngữ tài liệu/comment: **tiếng Việt** (giữ nhất quán với README/CHANGELOG hiện có).
- Thiết bị chạy 24/7, phần cứng bị cắt điện đột ngột ⇒ luôn ưu tiên độ tin cậy.

## Read first

1. [`README.md`](README.md) — stack, build, register map, REST API
2. [`docs/tt10-data-format.md`](docs/tt10-data-format.md) — định dạng file báo cáo (spec chính thức)
3. [`docs/provision-qr-v1.md`](docs/provision-qr-v1.md) — schema QR ghép nối với Central
4. [`CHANGELOG.md`](CHANGELOG.md) — lịch sử thay đổi

## Frozen contracts (chia sẻ với central_logger — KHÔNG tự ý đổi)

- **Provision QR**: `central-logger-provision/v1` — [`docs/provision-qr-v1.md`](docs/provision-qr-v1.md); bản central nằm ở `central_logger/docs/contracts/provision-qr-v1.md`.
- **REST `/api/v1/config` + `/api/v1/readings`**: edge là **Source of Truth** cấu hình cảm biến (xem README mục HTTP REST API). `POST /config` chỉ ghi app-config, không ghi trường cảm biến.
- **Modbus TCP register map v1** (HR 0..10+i*8): README mục Modbus TCP Server; bản central: `central_logger/docs/contracts/modbus-map-v1.md`.

Thay đổi bất kỳ contract nào cần **sự đồng ý rõ ràng của user** và update tài liệu cả 2 repo.

## Build

```bash
# Qt 6.13 (Online Installer), gcc-15; override QT_DIR nếu cần
./build.sh Release          # hoặc ./build.sh Debug
./build-release/bin/DataLogger
```

CI/`cmake` thủ công: `cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build`.
Target Qt: Core, Gui, Qml, Quick, QuickControls2, Sql, SerialBus, **HttpServer**, Graphs, Network (`find_package(Qt6 6.13 REQUIRED COMPONENTS ...)`).

## Test

```bash
cmake --build build-release --target tt10_test && (cd build-release && ctest --output-on-failure)
```

- Test hiện có: `tests/tt10_test.cpp` (ReportNaming, Tt10ReportWriter). Viết test mới dùng **Qt Test + CTest** (`tests/CMakeLists.txt` mẫu), target link `utils` + `datalogger_core`.
- Code thuần logic (codec, formula, naming, DAO) **bắt buộc kèm test** khi sửa.

## Kiến trúc

### Layers (CMake, chỉ phụ thuộc xuôi)

```
utils → data → network → core → theme → components → app
```

- `src/utils/` — tiện ích không phụ thuộc lớp trên (AppPaths, Crypto, Formula, ModbusCodec, LanIp, ProvisionQr, LogSetup, DeviceId/DeviceLock, ReportNaming)
- `src/data/` — `Database` (schema + migration + pragmas) + DAO (`SensorDao`, `SensorDataDao`, `ReportLogDao`, `AppConfigDao`) + models
- `src/network/` — `ModbusWorker` (RTU polling, QThread), `ModbusTcpServerService`, `RestApiService`, workers (`DatabaseWorker` batch insert, `FtpWorker`, `TesterWorker`)
- `src/core/` — Controllers/ViewModels cho QML (`MonitorController`, `ReportController`, `SettingsController`, `TesterController`, history/)
- `src/theme/`, `src/components/` — QML Material 3; `src/app/` — entry + QML shell

### Quy tắc

1. **MVVM**: business logic ở C++ Controller/Worker — **không** để logic nghiệp vụ trong QML hay `.js`.
2. **Threading**: Modbus RTU, DB batch, FTP, Tester chạy trên QThread riêng (`moveToThread` + `QThread::finished→deleteLater`). Cross-thread chỉ qua signal/slot (mặc nhiên queued). **Không** blocking I/O trên UI thread.
3. **SQLite**: mọi truy cập qua `Database::openConnection`/`ScopedDbConnection` (RAII, đặt tên connection theo thread) và DAO — không mở `QSqlDatabase` trực tiếp ở nơi khác. Schema thay đổi ⇒ **migration idempotent** trong `Database::migrate` (kiểm tra `PRAGMA table_info` trước khi ALTER).
4. **QML module**: `qt_add_qml_module`, register type bằng `QML_ELEMENT`/`QML_SINGLETON`; singleton helper: `src/utils/qml/QmlSingleton.h`.
5. **Prepared statements + bind value** cho mọi query — không ghép string SQL.
6. **Secret**: token REST tự sinh, **không** log token/password FTP, không hardcode secret. (Lưu ý: `Crypto` hiện là obfuscation Base64, không phải encryption — xem audit report ở thư mục cha.)

## Edge-specific rules

- Mọi chờ I/O (`QEventLoop`, `BlockingQueuedConnection`, `waitForFinished`) **phải có timeout**; không xóa `QThread` khi `wait()` timeout.
- Batch insert sensor_data luôn trong transaction; flush định kỳ qua `DatabaseWorker`.
- Báo cáo TT10: tên file/remote path theo `docs/tt10-data-format.md`; chỉ gửi ANALOG active có `transmit_enabled`; ký hiệu cảm biến theo Bảng 34 (`SensorSymbolCatalog.h`).
- Kiosk/Pi: thay đổi liên quan display/service ⇒ tham khảo `packaging/` (CPack deb, systemd, polkit) trong `cmake/CPackOptions.cmake` và `docs/raspberry-pi-waveshare-display.md`.

## CMake

- `cmake_minimum_required(3.16)`, `qt_standard_project_setup(REQUIRES 6.13)`, `QTP0004 NEW`, C++20, `CMAKE_AUTOMOC`/`CMAKE_AUTORCC` ON.
- Thêm lớp C++ mới ⇒ thêm file vào `CMakeLists.txt` của layer tương ứng; thêm thư viện mới phải respect thứ tự layers.
- Version: sửa `project(... VERSION)` trong `CMakeLists.txt` gốc (release sync bởi `sync_cmake_version.py`).
