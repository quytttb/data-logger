qt_add_library(utils STATIC
    AppPaths.cpp
    AppPaths.h
    LogSetup.cpp
    LogSetup.h
    Crypto.cpp
    Crypto.h
    LanIp.cpp
    LanIp.h
    Formula.cpp
    Formula.h
    ProvisionQr.cpp
    ProvisionQr.h
    third_party/qrcodegen.cpp
)

target_include_directories(utils PUBLIC ${CMAKE_SOURCE_DIR}/src)
target_include_directories(utils PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party
)

target_link_libraries(utils PUBLIC Qt6::Core Qt6::Network Qt6::Gui)

add_library(datalogger::utils ALIAS utils)
