pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    implicitHeight: 64

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: AppTheme.spacingS

        // Status pill: live monitoring state (read-only indicator, not a control)
        Rectangle {
            id: statusPill
            readonly property color stateColor: !MonitorController.isPolling
                ? AppColors.onSurfaceVariant
                : MonitorController.statusMode === MonitorController.StatusError ? AppColors.error : AppColors.success

            Layout.preferredHeight: 44
            Layout.preferredWidth: statusRow.implicitWidth + 36
            radius: AppTheme.listItemRadius
            color: AppColors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.rgba(statusPill.stateColor.r, statusPill.stateColor.g, statusPill.stateColor.b, 0.5)
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: AppTheme.spacingS

                Rectangle {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    radius: width / 2
                    color: statusPill.stateColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Label {
                    text: MonitorController.statusText
                    color: statusPill.stateColor
                    font.pixelSize: AppTypography.titleMedium.pixelSize
                    font.bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Clock and date (moved from sidebar)
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                id: clockTime
                text: Qt.formatDateTime(new Date(), SettingsController.timeFormat)
                font.pixelSize: AppTypography.titleLarge.pixelSize
                font.bold: true
                color: AppColors.primaryText
                horizontalAlignment: Text.AlignRight
            }

            Text {
                id: clockDate
                text: Qt.formatDateTime(new Date(), SettingsController.dateFormat)
                font.pixelSize: AppTypography.bodyMedium.pixelSize
                color: AppColors.onSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockTime.text = Qt.formatDateTime(new Date(), SettingsController.timeFormat)
            clockDate.text = Qt.formatDateTime(new Date(), SettingsController.dateFormat)
        }
    }
}
