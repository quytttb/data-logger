pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

Item {
    id: root
    implicitHeight: 64

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        // Status pill: live monitoring state (read-only indicator, not a control)
        Rectangle {
            id: statusPill
            readonly property color stateColor: !MonitorController.isPolling
                ? Theme.textSecondary
                : MonitorController.statusMode === 2 ? Theme.statusErrBright : Theme.statusOk

            Layout.preferredHeight: 44
            Layout.preferredWidth: statusRow.implicitWidth + 36
            radius: Theme.radiusMedium
            color: Theme.bgSeparator
            border.width: 1
            border.color: Qt.rgba(statusPill.stateColor.r, statusPill.stateColor.g, statusPill.stateColor.b, 0.5)
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

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
            radius: Theme.radiusSmall
            color: (MonitorController.watchdogStatus !== "OK" && MonitorController.watchdogStatus !== "N/A") || MonitorController.errorCount > 0 ? Theme.bgErrorTint : Theme.bgSeparator
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
                color: (MonitorController.watchdogStatus !== "OK" && MonitorController.watchdogStatus !== "N/A") || MonitorController.errorCount > 0 ? Theme.statusErr : Theme.textSecondary
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
            text: MonitorController.isStopping ? "Stopping…"
                : MonitorController.isPolling ? "Stop" : "Start"
            font.bold: true
            accent: MonitorController.isPolling ? Theme.btnStop : Theme.btnStart
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
