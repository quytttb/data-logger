set_source_files_properties(layout/AppNotifier.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(datalogger_components
    URI DataLogger.Components
    VERSION 1.0
    STATIC
    QML_FILES
        shell/AppSideBar.qml
        shell/MainHeaderChrome.qml
        shell/MonitorTaskBar.qml
        shell/HistoryTaskBar.qml
        shell/SettingsTaskBar.qml
        shell/TrendingTaskBar.qml
        shell/ModbusTesterTaskBar.qml
        layout/AppTextField.qml
        layout/AppNotifier.qml
        layout/AppToastHost.qml
        layout/MessageDetailDialog.qml
        layout/MessagePopup.qml
        layout/DatePickerPopup.qml
        layout/DateField.qml
        layout/ElevatedPane.qml
        layout/InlineBanner.qml
        layout/EmptyStatePlaceholder.qml
        layout/TableContentStack.qml
        table/AppTableView.qml
        table/TableHeaderCell.qml
        table/TableCellBackground.qml
        chart/ChartGraphsTheme.qml
        chart/ChartGraphsView.qml
        chart/ChartLinePointMarker.qml
        status/StatusChip.qml
        sensor/SensorConfigForm.qml
        sensor/SensorBasicTab.qml
        sensor/SensorScalingTab.qml
        sensor/SensorDigitalIOTab.qml
        sensor/ProvisionQrPopup.qml
    RESOURCES
        ../../resources/icons/monitor.svg
        ../../resources/icons/history.svg
        ../../resources/icons/chart.svg
        ../../resources/icons/settings.svg
        ../../resources/icons/tester.svg
        ../../resources/icons/connection.svg
        ../../resources/icons/export.svg
        ../../resources/icons/sensors.svg
        ../../resources/icons/delete.svg
        ../../resources/icons/edit.svg
        ../../resources/icons/search.svg
        ../../resources/icons/refresh.svg
        ../../resources/icons/qr.svg
    DEPENDENCIES
        datalogger_theme
        datalogger_core
        datalogger_network
)

set_target_properties(datalogger_components PROPERTIES QT_QMLLINT_MAX_WARNINGS 500)

add_library(datalogger::components ALIAS datalogger_components)
