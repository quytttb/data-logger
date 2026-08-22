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
                : MonitorController.statusMode === 2 ? AppColors.error : AppColors.success

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

        Rectangle {
            Layout.preferredWidth: errLabel.implicitWidth + 24
            Layout.preferredHeight: 32
            radius: AppTheme.listItemRadius
            color: (MonitorController.watchdogStatus !== "OK" && MonitorController.watchdogStatus !== "N/A") || MonitorController.errorCount > 0 ? AppColors.errorContainer : AppColors.surfaceContainerHigh
            visible: MonitorController.isPolling
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: errLabel
                anchors.centerIn: parent
                text: {
                    if (MonitorController.watchdogStatus !== "OK" && MonitorController.watchdogStatus !== "N/A")
                        return "SYSTEM FAULT - " + MonitorController.watchdogStatus;
                    if (MonitorController.errorCount > 0)
                        return "Modbus read errors: " + MonitorController.errorCount;
                    return "No read errors";
                }
                color: (MonitorController.watchdogStatus !== "OK" && MonitorController.watchdogStatus !== "N/A") || MonitorController.errorCount > 0 ? AppColors.error : AppColors.onSurfaceVariant
                font.pixelSize: AppTypography.labelMedium.pixelSize
                font.bold: true
            }
        }

        // Start/Stop control: placed far right to avoid accidental presses
        AppButton {
            enabled: !MonitorController.isStopping && (MonitorController.isPolling || MonitorController.hasActiveSensors)
            iconName: MonitorController.isStopping ? "refresh"
                : MonitorController.isPolling ? "stop" : "playArrow"
            iconSpinning: MonitorController.isStopping
            text: MonitorController.isStopping ? qsTr("Stopping…")
                : MonitorController.isPolling ? qsTr("Stop") : qsTr("Start")
            font.bold: true
            fillColor: MonitorController.isPolling ? AppColors.error : AppColors.success
            onClicked: {
                if (MonitorController.isPolling)
                    MonitorController.stopPolling()
                else
                    MonitorController.startPolling()
            }
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
