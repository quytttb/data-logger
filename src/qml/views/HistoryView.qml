import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Rectangle {
    id: histRoot
    color: "transparent"

    MessagePopup {
        id: histPopup
    }

    Connections {
        target: historyController
        function onMessageSent(t, m) { histPopup.showMessage(t, m) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 0

        // ── Card container (matches Settings form style) ─────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bgPanel
            radius: Theme.radiusCard
            border.color: Theme.borderDefault
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                // Table header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Theme.bgSeparator
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Label { text: "Time";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 160 }
                        Label { text: "Sensor";    color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 150 }
                        Label { text: "Unit";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 80 }
                        Label { text: "Value";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 120 }
                        Label { text: "Raw value"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.borderDefault
                }

                // Data rows — fill remaining space
                ListView {
                    id: historyList
                    clip: true
                    smooth: false
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: historyModel
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: historyList.width
                        height: 40
                        color: index % 2 === 0 ? Theme.bgPanel : Theme.bgStripe
                        radius: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            Text { text: model.recordedAt;  color: Theme.textLabel;     font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 160 }
                            Text { text: model.sensorName;  color: Theme.accentText;    font.pixelSize: Theme.fontLabelSize; font.bold: true; Layout.preferredWidth: 150; elide: Text.ElideRight }
                            Text { text: model.unit;        color: Theme.textLabel;     font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 80 }
                            Text { text: model.value;       color: Theme.statusOk;      font.pixelSize: 14; font.bold: true; font.family: "Monospace"; Layout.preferredWidth: 120 }
                            Text { text: model.rawValue;    color: Theme.textLabel;     font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: historyList.count === 0 && !historyController.isLoading
                        text: "No data.\nAdjust the time range or sensor, then search."
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: Math.min(400, parent.width - 32)
                    }
                }
            }
        }
    }
}
