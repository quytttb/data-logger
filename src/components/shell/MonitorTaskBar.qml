pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

Item {
    id: root
    implicitHeight: 64

    Popup {
        id: diLegendPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - 32)
        padding: Theme.spacingM
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.bgPanel
            radius: Theme.radiusCard
            border.color: Theme.accent
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingSM

            Text {
                text: "DI Status"
                font.bold: true; font.pixelSize: AppTypography.titleLarge.pixelSize
                color: Theme.textPrimary
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

            Repeater {
                model: MonitorController.diLegend

                RowLayout {
                    id: legendItem
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Rectangle {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        radius: width / 2
                        color: legendItem.modelData.color
                    }
                    Text {
                        text: legendItem.modelData.label
                        color: Theme.textPrimary
                        font.pixelSize: AppTypography.bodyMedium.pixelSize
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                visible: !MonitorController.diLegend || MonitorController.diLegend.length === 0
                text: "No DI channels configured."
                color: Theme.textSecondary
                font.pixelSize: AppTypography.bodyMedium.pixelSize
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.preferredHeight: 4 }

            AppButton {
                text: "OK"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 100
                onClicked: diLegendPopup.close()
            }
        }
    }

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

        Button {
            id: diLegendBtn
            visible: MonitorController.isPolling && MonitorController.diLegend && MonitorController.diLegend.length > 0
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignVCenter
            onClicked: diLegendPopup.open()

            contentItem: Row {
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: MonitorController.diLegend
                    Rectangle {
                        id: diDot
                        required property var modelData
                        width: 8; height: 8; radius: width / 2
                        color: diDot.modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: "DI Status"
                    color: AppColors.buttonText
                    font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.bgSeparator
                border.color: Theme.borderDefault
                border.width: 1
                opacity: diLegendBtn.pressed ? 0.7 : 1.0
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
