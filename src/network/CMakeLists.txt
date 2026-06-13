qt_add_library(network STATIC
    modbus/ModbusWorker.cpp
    modbus/ModbusWorker.h
    modbus/ModbusTcpServerService.cpp
    modbus/ModbusTcpServerService.h
    rest/RestApiService.cpp
    rest/RestApiService.h
    workers/DatabaseWorker.cpp
    workers/DatabaseWorker.h
    workers/FtpWorker.cpp
    workers/FtpWorker.h
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
