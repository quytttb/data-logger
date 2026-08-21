set_source_files_properties(layout/AppNotifier.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(shell/MaterialIcons.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(datalogger_components
    URI DataLogger.Components
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    STATIC
    QML_FILES
        shell/MaterialIcons.qml
        shell/UiIcon.qml
        shell/AppSideBar.qml
        shell/MainHeaderChrome.qml
        shell/MonitorTaskBar.qml
        shell/HistoryTaskBar.qml
        shell/SettingsTaskBar.qml
        shell/TrendingTaskBar.qml
        shell/ModbusTesterTaskBar.qml
        shell/AppButton.qml
        shell/ThemedTabButton.qml
        layout/AppTextField.qml
        layout/AppNotifier.qml
        layout/AppToastHost.qml
        layout/MessageDetailDialog.qml
        layout/MessagePopup.qml
        layout/DatePickerPopup.qml
        layout/DateField.qml
        layout/ElevatedPane.qml
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
        ../../resources/icons/brand_4m_technologies_blue.svg
        ../../resources/fonts/MaterialSymbols/MaterialSymbolsOutlined.ttf
    DEPENDENCIES
        datalogger_theme
        datalogger_core
        datalogger_network
)

set_target_properties(datalogger_components PROPERTIES QT_QMLLINT_MAX_WARNINGS 500)

add_library(datalogger::components ALIAS datalogger_components)
