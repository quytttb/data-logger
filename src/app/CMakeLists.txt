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
        datalogger_core
        datalogger_network
        datalogger_theme
        datalogger_components
)

set_target_properties(app PROPERTIES QT_QMLLINT_MAX_WARNINGS 500)

target_link_libraries(app PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Graphs
    datalogger_coreplugin
    datalogger_networkplugin
    datalogger_themeplugin
    datalogger_componentsplugin
    datalogger_core
    datalogger_network
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

install(FILES ${CMAKE_SOURCE_DIR}/packaging/linux/data-logger.desktop
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications
)

install(FILES ${CMAKE_SOURCE_DIR}/resources/app-icon.svg
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps
    RENAME data-logger.svg
)

install(FILES ${CMAKE_SOURCE_DIR}/resources/app-icon.png
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/256x256/apps
    RENAME data-logger.png
)
