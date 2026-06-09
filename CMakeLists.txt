cmake_minimum_required(VERSION 3.16)
project(DataLogger VERSION 1.0.0 LANGUAGES CXX)

# ── Qt 6.11 ───────────────────────────────────────────────────────────────
find_package(Qt6 6.11 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Qml
    Quick
    QuickControls2
    Sql
    SerialBus
    HttpServer
    Graphs
    Network
)

qt_standard_project_setup(REQUIRES 6.11)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# ── Source files ──────────────────────────────────────────────────────────
set(CPP_SOURCES
    src/main.cpp

    # Core
    src/core/Database.cpp
    src/core/AppPaths.cpp
    src/core/LogSetup.cpp
    src/core/Crypto.cpp
    src/core/LanIp.cpp
    src/core/TxtGenerator.cpp
    src/core/Formula.cpp

    # DAO
    src/core/dao/AppConfigDao.cpp
    src/core/dao/SensorDao.cpp
    src/core/dao/SensorDataDao.cpp
    src/core/dao/AnalogDigitalLinkDao.cpp
    src/core/dao/ReportLogDao.cpp

    # Workers
    src/workers/ModbusWorker.cpp
    src/workers/DatabaseWorker.cpp
    src/workers/FtpWorker.cpp

    # Modbus TCP / REST
    src/core/ModbusTcpServerService.cpp
    src/core/RestApiService.cpp

    # Models
    src/models/SensorListModel.cpp
    src/models/MonitorModel.cpp

    # Controllers
    src/controllers/SettingsController.cpp
    src/controllers/MonitorController.cpp
    src/controllers/HistoryController.cpp
    src/controllers/TesterController.cpp
    src/controllers/ReportController.cpp
)

set(QML_FILES
    src/qml/Main.qml
    src/qml/Theme.qml
    src/qml/MainTabContent.qml
    src/qml/shell/AppSideBar.qml
    src/qml/shell/MainHeaderChrome.qml
    src/qml/shell/MonitorTaskBar.qml
    src/qml/shell/HistoryTaskBar.qml
    src/qml/shell/SettingsTaskBar.qml
    src/qml/shell/TrendingTaskBar.qml
    src/qml/shell/ModbusTesterTaskBar.qml
    src/qml/views/MonitorView.qml
    src/qml/views/HistoryView.qml
    src/qml/views/TrendingView.qml
    src/qml/views/SettingsView.qml
    src/qml/views/SettingsGeneralTab.qml
    src/qml/views/SettingsConnectionTab.qml
    src/qml/views/SettingsSensorsTab.qml
    src/qml/views/SettingsServerTab.qml
    src/qml/views/TesterView.qml
    src/qml/views/TesterOperationsTab.qml
    src/qml/components/AppTextField.qml
    src/qml/components/MessagePopup.qml
    src/qml/components/ToastPopup.qml
    src/qml/components/DatePickerPopup.qml
    src/qml/components/ProvisionQrPopup.qml
    src/qml/components/SensorConfigForm.qml
    src/qml/components/SensorBasicTab.qml
    src/qml/components/SensorScalingTab.qml
    src/qml/components/SensorDigitalIOTab.qml
)

# ── Build target with qt_add_qml_module ───────────────────────────────────
qt_add_executable(DataLogger ${CPP_SOURCES})

qt_add_qml_module(DataLogger
    URI com.datalogger.app
    VERSION 1.0
    QML_FILES ${QML_FILES}
    RESOURCES
        assets/app-icon.svg
        assets/app-icon.png
)

# ── Link Qt modules ───────────────────────────────────────────────────────
target_link_libraries(DataLogger PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::SerialBus
    Qt6::HttpServer
    Qt6::Graphs
    Qt6::Network
)

target_include_directories(DataLogger PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# ── Install ───────────────────────────────────────────────────────────────
install(TARGETS DataLogger
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_qml_app_script(
    TARGET DataLogger
    OUTPUT_SCRIPT deploy_script
)
install(SCRIPT ${deploy_script})
