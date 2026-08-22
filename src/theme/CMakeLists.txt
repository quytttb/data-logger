# UI theme — edge-only QML singletons.
# Base tokens (AppColors / AppTheme / AppTypography / QuickControlsConfig) +
# ThemeSetup now live in the shared kit (LoggerKit.Theme). Only DI/DO indicator
# colors (no central_logger equivalent) stay here.

set_source_files_properties(IoColors.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(datalogger_theme
    URI DataLogger.Theme
    VERSION ${DATALOGGER_QML_MODULE_VERSION}
    STATIC
    QML_FILES
        IoColors.qml
    DEPENDENCIES
        LoggerKit.Theme
)

set_target_properties(datalogger_theme PROPERTIES QT_QMLLINT_MAX_WARNINGS 0)
set_target_properties(datalogger_core PROPERTIES QT_QMLLINT_MAX_WARNINGS 0)

add_library(datalogger::theme ALIAS datalogger_theme)
