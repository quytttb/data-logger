find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core Sql SerialBus Test Network)

add_executable(tt10_test tt10_test.cpp)
target_include_directories(tt10_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(tt10_test PRIVATE
    Qt6::Core
    Qt6::Sql
    utils
    datalogger_core
)
add_test(NAME tt10_test COMMAND tt10_test)

# QTest: codec endianness + formula (audit P2-14)
add_executable(codec_formula_test codec_formula_test.cpp)
target_include_directories(codec_formula_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(codec_formula_test PRIVATE
    Qt6::Core
    Qt6::SerialBus
    Qt6::Test
    utils
)
add_test(NAME codec_formula_test COMMAND codec_formula_test)

# QTest: AES-256-GCM credential crypto (audit C1)
add_executable(crypto_test crypto_test.cpp)
target_include_directories(crypto_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(crypto_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME crypto_test COMMAND crypto_test)

# QTest: alarm hysteresis band logic (audit M5 / P2-14)
add_executable(alarm_hysteresis_test alarm_hysteresis_test.cpp)
target_include_directories(alarm_hysteresis_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(alarm_hysteresis_test PRIVATE
    Qt6::Core
    Qt6::Test
    network
    data
    utils
)
add_test(NAME alarm_hysteresis_test COMMAND alarm_hysteresis_test)

# QTest: AppDefaults ↔ AppConfig ↔ ModbusCodec nhất quán (audit P2-14).
add_executable(app_defaults_test app_defaults_test.cpp)
target_include_directories(app_defaults_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(app_defaults_test PRIVATE
    Qt6::Core
    Qt6::Test
    data
    utils
)
add_test(NAME app_defaults_test COMMAND app_defaults_test)

# QTest: FtpClient (passive STOR + MKD -p) với fake FTP server in-process.
add_executable(ftp_client_test ftp_client_test.cpp)
target_include_directories(ftp_client_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(ftp_client_test PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Test
    network
)
add_test(NAME ftp_client_test COMMAND ftp_client_test)

# QTest: TimezoneOptions — single source of truth cho dropdown/migration/lookup.
add_executable(timezone_options_test timezone_options_test.cpp)
target_include_directories(timezone_options_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(timezone_options_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME timezone_options_test COMMAND timezone_options_test)

# QTest: SensorListModel form logic — validation + coefficient codec (no DB).
add_executable(sensor_form_test sensor_form_test.cpp)
target_include_directories(sensor_form_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(sensor_form_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME sensor_form_test COMMAND sensor_form_test)

# QTest: trend axis math (window/margin/digital-only range, no instance).
add_executable(trend_axes_test trend_axes_test.cpp)
target_include_directories(trend_axes_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(trend_axes_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME trend_axes_test COMMAND trend_axes_test)

# Integration: Modbus RTU master ↔ pymodbus slave trên cặp serial ảo (socat).
# Tự QSKIP nếu thiếu socat/python3/pymodbus — không bắt buộc trên mọi máy dev.
add_executable(integration_modbus_test integration_modbus_test.cpp)
target_compile_definitions(integration_modbus_test PRIVATE
    SIMULATOR_SCRIPT_PATH="${CMAKE_SOURCE_DIR}/tools/simulator/modbus_rtu_simulator.py")
target_link_libraries(integration_modbus_test PRIVATE
    Qt6::Core
    Qt6::SerialBus
    Qt6::SerialPort
    Qt6::Test
)
add_test(NAME integration_modbus_test COMMAND integration_modbus_test)

# QTest: DeviceLock state machine (Unbound/Authorized/Unauthorized + tamper detection)
add_executable(device_lock_test device_lock_test.cpp)
target_include_directories(device_lock_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(device_lock_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    utils
    data
)
add_test(NAME device_lock_test COMMAND device_lock_test)

# QTest: MonitorController retry backoff calculation
add_executable(monitor_retry_test monitor_retry_test.cpp)
target_include_directories(monitor_retry_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(monitor_retry_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME monitor_retry_test COMMAND monitor_retry_test)

# QTest: LocaleOptions — vi/en UI locale list (single source of truth).
add_executable(locale_options_test locale_options_test.cpp)
target_include_directories(locale_options_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(locale_options_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME locale_options_test COMMAND locale_options_test)

# QTest: JsonTableModel — multi-column bridge for AppTableView.
add_executable(json_table_model_test json_table_model_test.cpp)
target_include_directories(json_table_model_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(json_table_model_test PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    datalogger_core
)
add_test(NAME json_table_model_test COMMAND json_table_model_test)

# QTest: SensorSymbols.displayLabel — tên đầy đủ Symbol_Tên.
add_executable(sensor_symbols_test sensor_symbols_test.cpp)
target_include_directories(sensor_symbols_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(sensor_symbols_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME sensor_symbols_test COMMAND sensor_symbols_test)

# QTest: MonitorTableModel — AppTableView bridge cho MonitorModel (lọc DI/DO, live update).
add_executable(monitor_table_model_test monitor_table_model_test.cpp)
target_include_directories(monitor_table_model_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(monitor_table_model_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME monitor_table_model_test COMMAND monitor_table_model_test)

# QTest: HistoryTableModel — setRows thay thế + appendRows nạp theo chunk.
add_executable(history_table_model_test history_table_model_test.cpp)
target_include_directories(history_table_model_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(history_table_model_test PRIVATE
    Qt6::Core
    Qt6::Test
    datalogger_core
)
add_test(NAME history_table_model_test COMMAND history_table_model_test)

# QTest: retention sensor_data 30 ngày (đồng bộ file TXT gửi Sở) — cutoff + chunked delete.
add_executable(retention_test retention_test.cpp)
target_include_directories(retention_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(retention_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    data
    utils
)
add_test(NAME retention_test COMMAND retention_test)

# QTest: Downsampler min-max bucket — giữ đỉnh/alarm, chặn output ~800.
add_executable(downsampler_test downsampler_test.cpp)
target_include_directories(downsampler_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(downsampler_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME downsampler_test COMMAND downsampler_test)

# QTest: ModbusPortGuard RAII — single-owner cổng RS-485 (chống SEGV Tester Connect).
add_executable(port_guard_test port_guard_test.cpp)
target_include_directories(port_guard_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(port_guard_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME port_guard_test COMMAND port_guard_test)


# QTest: KDF PBKDF2-HMAC-SHA256 (Slice 0 RBAC) — vector chuẩn + định dạng lưu.
add_executable(password_hasher_test password_hasher_test.cpp)
target_include_directories(password_hasher_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(password_hasher_test PRIVATE
    Qt6::Core
    Qt6::Test
    utils
)
add_test(NAME password_hasher_test COMMAND password_hasher_test)

# QTest: schema version + user_account/audit_log DAO (Slice 0).
add_executable(auth_data_test auth_data_test.cpp)
target_include_directories(auth_data_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(auth_data_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    data
    utils
)
add_test(NAME auth_data_test COMMAND auth_data_test)

# QTest: calibration_session/point DAO + transaction chung + cascade.
add_executable(calibration_dao_test calibration_dao_test.cpp)
target_include_directories(calibration_dao_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(calibration_dao_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    data
    utils
)
add_test(NAME calibration_dao_test COMMAND calibration_dao_test)

# QTest: AuthService — tạo admin đầu tiên, đăng nhập/khóa phiên, RBAC backend,
# đổi mật khẩu bắt buộc và bảo vệ admin cuối cùng (Slice 1).
add_executable(auth_service_test auth_service_test.cpp)
target_include_directories(auth_service_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(auth_service_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    datalogger_core
)
add_test(NAME auth_service_test COMMAND auth_service_test)

# QTest: audit log — transaction nghiệp vụ, chặn quyền xem, không lộ secret.
add_executable(audit_test audit_test.cpp)
target_include_directories(audit_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(audit_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    datalogger_core
)
add_test(NAME audit_test COMMAND audit_test)

# QTest: hồi quy đa điểm, áp dụng nguyên tử, RBAC, audit và cascade.
add_executable(calibration_test calibration_test.cpp)
target_include_directories(calibration_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(calibration_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    datalogger_core
    utils
)
add_test(NAME calibration_test COMMAND calibration_test)

# QTest: REST v1 config + actor thiết bị từ xa + rollback khi audit lỗi.
add_executable(rest_config_test rest_config_test.cpp)
target_include_directories(rest_config_test PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(rest_config_test PRIVATE
    Qt6::Core
    Qt6::Sql
    Qt6::Test
    datalogger_network
)
add_test(NAME rest_config_test COMMAND rest_config_test)
