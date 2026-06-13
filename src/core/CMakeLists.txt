qt_add_library(core STATIC
    SettingsController.cpp
    SettingsController.h
    MonitorController.cpp
    MonitorController.h
    HistoryController.cpp
    HistoryController.h
    TesterController.cpp
    TesterController.h
    ReportController.cpp
    ReportController.h
    MonitorModel.cpp
    MonitorModel.h
    SensorListModel.cpp
    SensorListModel.h
)

set_target_properties(core PROPERTIES AUTOMOC ON)

target_include_directories(core PUBLIC ${CMAKE_SOURCE_DIR}/src)
target_include_directories(core PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(core PUBLIC
    Qt6::Core
    Qt6::Qml
    data
    network
    utils
)

add_library(datalogger::core ALIAS core)
