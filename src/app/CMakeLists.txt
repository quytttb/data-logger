# Binary "DataLogger", target "app" (avoids collision with QML output folder DataLogger/).

qt_add_executable(app
    main.cpp
)

set_target_properties(app PROPERTIES
    OUTPUT_NAME DataLogger
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

target_compile_definitions(app PRIVATE APP_VERSION="${APP_VERSION}")

# ThemeSetup.h ships with the shared kit (LoggerKit.Theme).
target_include_directories(app PRIVATE
    ${CMAKE_SOURCE_DIR}/shared/logger-ui-kit/src/theme
)

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_link_options(app PRIVATE -s)
endif()

qt_add_qml_module(app
    URI DataLogger.App
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    QML_FILES
        qml/Main.qml
        qml/OnScreenKeyboard.qml
        qml/MainTabContent.qml
        qml/views/MonitorView.qml
        qml/views/HistoryView.qml
        qml/views/TrendingView.qml
        qml/views/SettingsView.qml
        qml/views/SettingsGeneralTab.qml
        qml/views/SettingsConnectionTab.qml
        qml/views/SettingsSensorsTab.qml
        qml/views/SettingsServerTab.qml
        qml/views/SettingsTransmissionTab.qml
        qml/views/TesterView.qml
        qml/views/TesterOperationsTab.qml
        qml/LockScreen.qml
    RESOURCES
        ../../resources/app-icon.svg
        ../../resources/app-icon.png
    DEPENDENCIES
        LoggerKit.Theme
        LoggerKit.Components
        datalogger_core
        datalogger_network
        datalogger_theme
        datalogger_components
)

set_target_properties(app PROPERTIES QT_QMLLINT_MAX_WARNINGS 200)

target_link_libraries(app PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Graphs
    logger_ui_kit_themeplugin
    logger_ui_kit_componentsplugin
    LoggerKit::theme_setup
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

# systemd unit for headless kiosk autostart (installed to /usr/lib/systemd/system).
# Enabled/started automatically by the Debian maintainer scripts (see CPackOptions).
install(FILES ${CMAKE_SOURCE_DIR}/packaging/linux/datalogger.service
    DESTINATION lib/systemd/system
)

# polkit rules so the unprivileged kiosk user may reboot/power off (System
# Reboot button) and change the system timezone (Timezone setting) via the
# in-app settings. The service has no login session, so logind/timedated would
# otherwise require admin auth. polkit reads rules from /usr/share/polkit-1/rules.d.
install(FILES
        ${CMAKE_SOURCE_DIR}/packaging/linux/polkit/49-datalogger-reboot.rules
        ${CMAKE_SOURCE_DIR}/packaging/linux/polkit/49-datalogger-timedate.rules
    DESTINATION share/polkit-1/rules.d
)

# --- Headless / framebuffer support (e.g. Raspberry Pi OS Lite, no X11/Wayland) ---
# qt_generate_deploy_qml_app_script() only ships the desktop (xcb) platform plugin
# and skips ICU (treated as a system library). Running directly on DRM/KMS without
# a desktop environment additionally needs the eglfs platform plugin + a KMS/GBM
# device integration, and a bundled ICU so the app does not depend on the target's
# ICU major version matching the build host.
if(UNIX AND NOT APPLE AND NOT ANDROID AND NOT IOS)
    if(DEFINED QT6_INSTALL_PREFIX)
        set(_dl_qt_prefix "${QT6_INSTALL_PREFIX}")
    else()
        get_filename_component(_dl_qt_prefix "${Qt6_DIR}/../../.." ABSOLUTE)
    endif()

    if(DEFINED QT6_INSTALL_PLUGINS)
        set(_dl_qt_plugins "${_dl_qt_prefix}/${QT6_INSTALL_PLUGINS}")
    else()
        set(_dl_qt_plugins "${_dl_qt_prefix}/plugins")
    endif()

    # eglfs QPA platform plugin (loads libQt6EglFSDeviceIntegration, already deployed).
    install(FILES "${_dl_qt_plugins}/platforms/libqeglfs.so"
        DESTINATION plugins/platforms
        OPTIONAL)

    # Qt Virtual Keyboard input-context plugin — required so QT_IM_MODULE=
    # qtvirtualkeyboard resolves on the target (the on-screen touch keyboard).
    # The accompanying QML/runtime modules are handled by the deploy script above.
    install(DIRECTORY "${_dl_qt_plugins}/platforminputcontexts/"
        DESTINATION plugins/platforminputcontexts
        FILES_MATCHING PATTERN "libqtvirtualkeyboardplugin.so")

    # KMS/GBM (and EGLDevice) integrations — backend used by eglfs on the Pi GPU.
    install(DIRECTORY "${_dl_qt_plugins}/egldeviceintegrations/"
        DESTINATION plugins/egldeviceintegrations
        FILES_MATCHING PATTERN "libqeglfs-kms*-integration.so")

    # Bundle ICU next to the Qt libraries (app RPATH already resolves /usr/lib).
    file(GLOB _dl_icu_libs
        "${_dl_qt_prefix}/lib/libicudata.so.*"
        "${_dl_qt_prefix}/lib/libicui18n.so.*"
        "${_dl_qt_prefix}/lib/libicuuc.so.*"
        "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/libicudata.so.*"
        "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/libicui18n.so.*"
        "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}/libicuuc.so.*")
    if(_dl_icu_libs)
        install(FILES ${_dl_icu_libs}
            DESTINATION ${CMAKE_INSTALL_LIBDIR})
    endif()
endif()
