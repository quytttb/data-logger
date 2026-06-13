set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(datalogger_theme
    URI DataLogger.Theme
    VERSION 1.0
    STATIC
    QML_FILES
        Theme.qml
    RESOURCES
        qtquickcontrols2.conf
)

add_library(datalogger::theme ALIAS datalogger_theme)
