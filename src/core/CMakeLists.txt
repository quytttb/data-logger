# Core layer — C++ singletons/controllers exposed to QML as DataLogger.Core

qt_add_qml_module(datalogger_core
    URI DataLogger.Core
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    STATIC
    SOURCES
        AppDefaults.cpp
        AppDefaults.h
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
        tt10/SensorSymbols.cpp
        tt10/SensorSymbols.h
        tt10/Tt10ReportWriter.cpp
        tt10/Tt10ReportWriter.h
)

target_include_directories(datalogger_core
    PUBLIC ${CMAKE_SOURCE_DIR}/src
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/history
        ${CMAKE_CURRENT_SOURCE_DIR}/tt10
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
