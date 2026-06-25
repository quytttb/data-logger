qt_add_library(utils STATIC
    # system — paths, device identity, logging bootstrap
    system/AppPaths.cpp
    system/AppPaths.h
    system/DeviceId.cpp
    system/DeviceId.h
    system/LogSetup.cpp
    system/LogSetup.h

    # network
    network/LanIp.cpp
    network/LanIp.h

    # crypto
    crypto/Crypto.cpp
    crypto/Crypto.h

    # modbus — register codec and sensor formula helpers
    modbus/Formula.cpp
    modbus/Formula.h
    modbus/ModbusCodec.cpp
    modbus/ModbusCodec.h

    # provision — QR onboarding payload
    provision/ProvisionQr.cpp
    provision/ProvisionQr.h
    provision/third_party/qrcodegen.cpp
)

target_include_directories(utils PUBLIC ${CMAKE_SOURCE_DIR}/src)
target_include_directories(utils PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/provision/third_party
)

target_link_libraries(utils PUBLIC Qt6::Core Qt6::Network Qt6::Gui Qt6::SerialBus)

add_library(datalogger::utils ALIAS utils)
