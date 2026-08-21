find_package(Qt6 6.13 REQUIRED COMPONENTS Core Sql SerialBus Test)

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
