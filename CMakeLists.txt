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
    ui/qml/Main.qml
    ui/qml/Theme.qml
    ui/qml/MainTabContent.qml
    ui/qml/shell/AppSideBar.qml
    ui/qml/shell/MainHeaderChrome.qml
    ui/qml/shell/MonitorTaskBar.qml
    ui/qml/shell/HistoryTaskBar.qml
    ui/qml/shell/SettingsTaskBar.qml
    ui/qml/shell/TrendingTaskBar.qml
    ui/qml/shell/ModbusTesterTaskBar.qml
    ui/qml/views/MonitorView.qml
    ui/qml/views/HistoryView.qml
    ui/qml/views/TrendingView.qml
    ui/qml/views/SettingsView.qml
    ui/qml/views/SettingsGeneralTab.qml
    ui/qml/views/SettingsConnectionTab.qml
    ui/qml/views/SettingsSensorsTab.qml
    ui/qml/views/SettingsServerTab.qml
    ui/qml/views/TesterView.qml
    ui/qml/views/TesterOperationsTab.qml
    ui/qml/components/AppTextField.qml
    ui/qml/components/MessagePopup.qml
    ui/qml/components/ToastPopup.qml
    ui/qml/components/DatePickerPopup.qml
    ui/qml/components/ProvisionQrPopup.qml
    ui/qml/components/SensorConfigForm.qml
    ui/qml/components/SensorBasicTab.qml
    ui/qml/components/SensorScalingTab.qml
    ui/qml/components/SensorDigitalIOTab.qml
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
