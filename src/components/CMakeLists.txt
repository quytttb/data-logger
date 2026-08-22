# Edge-specific QML components (shell chrome, sensor forms, message popup).
# Generic shell/layout/table/chart/status chrome now lives in LoggerKit.Components.
qt_add_qml_module(datalogger_components
    URI DataLogger.Components
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    STATIC
    QML_FILES
        shell/AppSideBar.qml
        shell/MainHeaderChrome.qml
        shell/MonitorTaskBar.qml
        shell/HistoryTaskBar.qml
        shell/SettingsTaskBar.qml
        shell/TrendingTaskBar.qml
        shell/ModbusTesterTaskBar.qml
        shell/ThemedTabButton.qml
        layout/MessagePopup.qml
        sensor/SensorConfigForm.qml
        sensor/SensorBasicTab.qml
        sensor/SensorScalingTab.qml
        sensor/SensorDigitalIOTab.qml
        sensor/ProvisionQrPopup.qml
    DEPENDENCIES
        LoggerKit.Theme
        LoggerKit.Components
        datalogger_theme
        datalogger_core
        datalogger_network
)

set_target_properties(datalogger_components PROPERTIES QT_QMLLINT_MAX_WARNINGS 0)

add_library(datalogger::components ALIAS datalogger_components)
