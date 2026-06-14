# Core layer — C++ singletons/controllers exposed to QML as DataLogger.Core

qt_add_qml_module(datalogger_core
    URI DataLogger.Core
    VERSION 1.0
    STATIC
    SOURCES
        SettingsController.cpp
        SettingsController.h
        MonitorController.cpp
        MonitorController.h
        history/HistoryViewModel.cpp
        history/HistoryViewModel.h
        history/HistoryTableModel.cpp
        history/HistoryTableModel.h
        TesterController.cpp
        TesterController.h
        ReportController.cpp
        ReportController.h
        MonitorModel.cpp
        MonitorModel.h
        SensorListModel.cpp
        SensorListModel.h
)

target_include_directories(datalogger_core
    PUBLIC ${CMAKE_SOURCE_DIR}/src
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/history
)

target_link_libraries(datalogger_core PUBLIC
    Qt6::Core
    Qt6::Concurrent
    Qt6::Qml
    data
    network
    datalogger_network
    utils
)

add_library(datalogger::core ALIAS datalogger_core)
