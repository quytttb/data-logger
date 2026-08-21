set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(AppColors.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(AppTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(AppTypography.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(datalogger_theme
    URI DataLogger.Theme
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    STATIC
    QML_FILES
        AppColors.qml
        AppTheme.qml
        AppTypography.qml
        Theme.qml
    RESOURCES
        qtquickcontrols2.conf
)

set_target_properties(datalogger_theme PROPERTIES QT_QMLLINT_MAX_WARNINGS 500)
set_target_properties(datalogger_core PROPERTIES QT_QMLLINT_MAX_WARNINGS 500)

add_library(datalogger::theme ALIAS datalogger_theme)
