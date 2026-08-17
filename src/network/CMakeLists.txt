qt_add_library(network STATIC
    modbus/ModbusWorker.cpp
    modbus/ModbusWorker.h
    workers/DatabaseWorker.cpp
    workers/DatabaseWorker.h
    workers/FtpWorker.cpp
    workers/FtpWorker.h
    workers/RetentionWorker.cpp
    workers/RetentionWorker.h
    workers/TesterWorker.cpp
    workers/TesterWorker.h
)

set_target_properties(network PROPERTIES AUTOMOC ON)

target_include_directories(network PUBLIC ${CMAKE_SOURCE_DIR}/src)
target_include_directories(network PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/modbus
    ${CMAKE_CURRENT_SOURCE_DIR}/rest
    ${CMAKE_CURRENT_SOURCE_DIR}/workers
)

target_link_libraries(network PUBLIC
    Qt6::Core
    Qt6::Network
    Qt6::SerialBus
    Qt6::HttpServer
    data
    utils
)

add_library(datalogger::network ALIAS network)

# LAN-facing services exposed to QML as DataLogger.Network
qt_add_qml_module(datalogger_network
    URI DataLogger.Network
    VERSION 1.0
    STATIC
    SOURCES
        modbus/ModbusTcpServerService.cpp
        modbus/ModbusTcpServerService.h
        rest/RestApiService.cpp
        rest/RestApiService.h
)

target_include_directories(datalogger_network
    PUBLIC ${CMAKE_SOURCE_DIR}/src
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/modbus
        ${CMAKE_CURRENT_SOURCE_DIR}/rest
)

target_link_libraries(datalogger_network PUBLIC
    Qt6::Core
    Qt6::Network
    Qt6::SerialBus
    Qt6::HttpServer
    Qt6::Qml
    data
    utils
)
