import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DataLogger.Theme

Item {
    id: root

    property string label: ""
    property string displayStatus: ""
    property bool indicatorActive: false
    property color indicatorActiveColor: AppColors.success
    property color indicatorInactiveColor: AppColors.outline

    readonly property string normalizedStatus: String(displayStatus || "").toUpperCase()
    readonly property bool indicatorMode: label.length > 0
    readonly property bool hasContent: indicatorMode || normalizedStatus.length > 0

    readonly property string chipText: indicatorMode ? label : normalizedStatus

    readonly property color chipFill: {
        if (indicatorMode) return "transparent"
        if (normalizedStatus === "OK" || normalizedStatus === "ON") return AppColors.withAlpha(AppColors.success, 0.18)
        if (normalizedStatus === "ERR" || normalizedStatus === "OFF") return AppColors.withAlpha(AppColors.error, 0.18)
        return AppColors.withAlpha(AppColors.onSurfaceVariant, 0.18)
    }

    readonly property color chipBorder: {
        if (indicatorMode) return indicatorActive ? indicatorActiveColor : indicatorInactiveColor
        if (normalizedStatus === "OK" || normalizedStatus === "ON") return AppColors.success
        if (normalizedStatus === "ERR") return AppColors.error
        return AppColors.outline
    }

    readonly property color chipTextColor: {
        if (indicatorMode) return indicatorActive ? indicatorActiveColor : indicatorInactiveColor
        if (normalizedStatus === "OK" || normalizedStatus === "ON") return AppColors.success
        if (normalizedStatus === "ERR") return AppColors.error
        return AppColors.onSurfaceVariant
    }

    readonly property int chipHeight: indicatorMode ? 30 : 24

    implicitHeight: hasContent ? chipHeight : 0
    implicitWidth: hasContent ? chipBox.width : 0
    visible: hasContent

    Rectangle {
        id: chipBox
        anchors.verticalCenter: parent.verticalCenter
        height: root.chipHeight
        width: chipContent.implicitWidth + (root.indicatorMode ? 28 : 24)
        radius: root.indicatorMode ? height / 2 : AppTheme.chipRadius
        color: root.chipFill
        border.width: 1
        border.color: root.chipBorder

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: root.indicatorMode ? 6 : 4

            Rectangle {
                visible: root.indicatorMode
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: width / 2
                color: root.indicatorActive ? root.indicatorActiveColor : root.indicatorInactiveColor
            }

            Label {
                text: root.chipText
                font: AppTypography.labelSmall
                color: root.chipTextColor
                elide: Text.ElideNone
                maximumLineCount: 1
            }
        }
    }
}
