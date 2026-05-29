import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Thanh header Monitor: start/stop + trạng thái (statusText từ Python tr()).
Item {
    id: root
    implicitHeight: 64

    // ── DI Legend Popup ──────────────────────────────────────────────────
    Popup {
        id: diLegendPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - 32)
        padding: 18
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
            spacing: 12

            Text {
                text: "DI Status"
                font.bold: true; font.pixelSize: 18
                color: Theme.textPrimary
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

            Repeater {
                model: monitorController.diLegend

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: modelData.color
                    }
                    Text {
                        text: modelData.label
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                visible: !monitorController.diLegend || monitorController.diLegend.length === 0
                text: "No DI channels configured."
                color: Theme.textSecondary
                font.pixelSize: 14
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.preferredHeight: 4 }

            Button {
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
        spacing: 10

        Button {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 44
            enabled: !monitorController.isStopping && (monitorController.isPolling || monitorController.hasActiveSensors)
            text: monitorController.isStopping ? "Stopping…"
                : monitorController.isPolling ? "Stop monitoring" : "Start monitoring"
            font.pixelSize: 14
            font.bold: true
            background: Rectangle {
                radius: Theme.radiusMedium
                color: !parent.enabled ? Theme.btnBgDisabled
                     : monitorController.isPolling ? Theme.btnStop : Theme.btnStart
                opacity: parent.pressed ? 0.75 : 1.0
            }
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: Theme.textOnColoredBtn
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: {
                if (monitorController.isPolling)
                    monitorController.stop_polling()
                else
                    monitorController.start_polling()
            }
            Layout.alignment: Qt.AlignVCenter
        }

        BusyIndicator {
            running: monitorController.isStopping
            visible: monitorController.isStopping
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            radius: 6
            color: {
                if (!monitorController.isPolling)
                    return Theme.textSecondary
                return monitorController.statusMode === 2 ? Theme.statusErrBright : Theme.statusOk
            }
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            text: monitorController.statusText
            color: Theme.textPrimary
            font.pixelSize: 14
            font.bold: true
            Layout.minimumWidth: 80
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        // ── DI Legend button ─────────────────────────────────────────────
        Button {
            visible: monitorController.isPolling && monitorController.diLegend && monitorController.diLegend.length > 0
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignVCenter
            onClicked: diLegendPopup.open()

            contentItem: Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                // Mini dots preview
                Repeater {
                    model: monitorController.diLegend
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: "DI Status"
                    color: Theme.textPrimary
                    font.pixelSize: 12; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.bgSeparator
                border.color: Theme.borderDefault
                border.width: 1
                opacity: parent.pressed ? 0.7 : 1.0
            }
        }

        Item { Layout.fillWidth: true }


        Rectangle {
            Layout.preferredWidth: errLabel.implicitWidth + 24
            Layout.preferredHeight: 32
            radius: Theme.radiusSmall
            color: (monitorController.watchdogStatus !== "OK" && monitorController.watchdogStatus !== "N/A") || monitorController.errorCount > 0 ? Theme.bgErrorTint : Theme.bgSeparator
            visible: monitorController.isPolling
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: errLabel
                anchors.centerIn: parent
                text: {
                    if (monitorController.watchdogStatus !== "OK" && monitorController.watchdogStatus !== "N/A")
                        return "SYSTEM FAULT - " + monitorController.watchdogStatus;
                    if (monitorController.errorCount > 0)
                        return "Modbus read errors: " + monitorController.errorCount;
                    return "No read errors";
                }
                color: (monitorController.watchdogStatus !== "OK" && monitorController.watchdogStatus !== "N/A") || monitorController.errorCount > 0 ? Theme.statusErr : Theme.textSecondary
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
