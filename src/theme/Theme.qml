pragma Singleton
import QtQuick

// Backward-compatible aliases — prefer AppColors / AppTheme / AppTypography in new code.
QtObject {

    readonly property color bgDeep:      AppColors.surface
    readonly property color bgPanel:     AppColors.surfaceContainerLow
    readonly property color bgStripe:    AppColors.surfaceContainer
    readonly property color bgSeparator: AppColors.surfaceContainerHigh
    readonly property color bgInput:     AppColors.surfaceContainerHigh
    readonly property color bgErrorTint: AppColors.errorContainer

    readonly property color surface:                AppColors.surface
    readonly property color surfaceContainerLow:    AppColors.surfaceContainerLow
    readonly property color surfaceContainer:       AppColors.surfaceContainer
    readonly property color surfaceContainerHigh:   AppColors.surfaceContainerHigh
    readonly property color surfaceContainerHighest: AppColors.surfaceContainerHigh

    readonly property color accent:      AppColors.primaryColor
    readonly property color accentText:  AppColors.accentColor

    readonly property color primary:            AppColors.primaryColor
    readonly property color primaryContainer:   AppColors.accentContainer
    readonly property color onPrimary:          AppColors.onPrimary
    readonly property color onPrimaryContainer: AppColors.accentContainerFg

    readonly property color textPrimary:      AppColors.primaryText
    readonly property color textSecondary:    AppColors.onSurfaceVariant
    readonly property color textLabel:        AppColors.onSurfaceVariant
    readonly property int   fontLabelSize:    14
    readonly property color textDim:          AppColors.textMuted
    readonly property color textFaint:        AppColors.textFaint
    readonly property color textOnColoredBtn: AppColors.buttonTextOnFilled

    readonly property color onSurface:         AppColors.primaryText
    readonly property color onSurfaceVariant:  AppColors.onSurfaceVariant
    readonly property color primaryText:       AppColors.primaryText

    readonly property color statusOk:         AppColors.success
    readonly property color statusErr:        AppColors.error
    readonly property color statusErrBright:  AppColors.error
    readonly property color statusWarn:       AppColors.warning

    readonly property color success: AppColors.success
    readonly property color error:   AppColors.error
    readonly property color warning: AppColors.warning

    readonly property color borderOk:      AppColors.success
    readonly property color borderErr:     AppColors.error
    readonly property color borderDefault: AppColors.outlineVariant

    readonly property color elevatedBorder: AppColors.elevatedBorder

    readonly property color btnStart:       AppColors.success
    readonly property color btnStop:        AppColors.error
    readonly property color btnClear:       AppColors.warning
    readonly property color btnClearText:   AppColors.buttonTextOnFilled
    readonly property color buttonIcon:     AppColors.buttonIcon
    readonly property color buttonIconOnFilled: AppColors.buttonIconOnFilled
    readonly property color btnBgDisabled:  AppColors.disabledContent
    readonly property color btnBgMuted:     AppColors.surfaceContainerHigh

    readonly property int radiusCard:   AppTheme.cardRadius
    readonly property int radiusSmall:   AppTheme.listItemRadius
    readonly property int radiusTiny:    4
    readonly property int radiusMedium:  AppTheme.listItemRadius
    readonly property int chipRadius:    AppTheme.chipRadius
    readonly property int listItemRadius: AppTheme.listItemRadius

    readonly property int spacingXS:   4
    readonly property int spacingS:    8
    readonly property int spacingSM:  12
    readonly property int spacingM:   16
    readonly property int spacingL:   24
    readonly property int sectionSpacing: AppTheme.sectionSpacing

    readonly property int typeTitleLarge:   22
    readonly property int typeTitleMedium:  16
    readonly property int typeBodyLarge:    16
    readonly property int typeBodyMedium:   14
    readonly property int typeLabelLarge:   14
    readonly property int typeLabelMedium:  12
    readonly property int typeLabelSmall:   11

    readonly property var chartSeriesColors: AppColors.graphSeriesColors
    readonly property var graphSeriesColors: AppColors.graphSeriesColors
}
