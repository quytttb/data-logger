# Binary "DataLogger", target "app" (avoids collision with QML output folder DataLogger/).

qt_add_executable(app
    main.cpp
)

set_target_properties(app PROPERTIES
    OUTPUT_NAME DataLogger
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

qt_add_qml_module(app
    URI DataLogger.App
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/MainTabContent.qml
        qml/views/MonitorView.qml
        qml/views/HistoryView.qml
        qml/views/TrendingView.qml
        qml/views/SettingsView.qml
        qml/views/SettingsGeneralTab.qml
        qml/views/SettingsConnectionTab.qml
        qml/views/SettingsSensorsTab.qml
        qml/views/SettingsServerTab.qml
        qml/views/TesterView.qml
        qml/views/TesterOperationsTab.qml
    RESOURCES
        ../../resources/app-icon.svg
        ../../resources/app-icon.png
    DEPENDENCIES
        datalogger_theme
        datalogger_components
)

target_link_libraries(app PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Graphs
    datalogger_themeplugin
    datalogger_componentsplugin
    core
    network
    data
    utils
)

qt_generate_deploy_qml_app_script(
    TARGET app
    OUTPUT_SCRIPT deploy_script
)

install(TARGETS app
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(SCRIPT ${deploy_script})
