import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: histRoot
    color: "transparent"

    // ── Message Popup ─────────────────────────────────────────────────────
    Popup {
        id: histPopup
        anchors.centerIn: parent
        width: 360
        height: 160
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.bgSeparator
            radius: 8
            border.color: Theme.accent
            border.width: 2
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            Text {
                id: histPopTitle
                font.bold: true
                font.pixelSize: 18
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                id: histPopMsg
                wrapMode: Text.WordWrap
                color: Theme.accentText
                font.pixelSize: 14
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Button {
                text: qsTr("Close")
                Layout.alignment: Qt.AlignHCenter
                onClicked: histPopup.close()
            }
        }
    }

    Connections {
        target: historyController
        function onMessageSent(t, m) {
            histPopTitle.text = t;
            histPopMsg.text = m;
            histPopup.open();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // ── Table Header ──────────────────────────────────────────────────
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
                Label {
                    text: qsTr("Time")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 160
                }
                Label {
                    text: qsTr("Sensor")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 150
                }
                Label {
                    text: qsTr("Unit")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 80
                }
                Label {
                    text: qsTr("Value")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 120
                }
                Label {
                    text: qsTr("Raw value")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }
        }

        // ── Data List ─────────────────────────────────────────────────────
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: historyModel
            clip: true
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
                    Text {
                        text: model.recordedAt
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        Layout.preferredWidth: 160
                    }
                    Text {
                        text: model.sensorName
                        color: Theme.accentText
                        font.pixelSize: 13
                        font.bold: true
                        Layout.preferredWidth: 150
                        elide: Text.ElideRight
                    }
                    Text {
                        text: model.unit
                        color: Theme.textSecondary
                        font.pixelSize: 13
                        Layout.preferredWidth: 80
                    }
                    Text {
                        text: model.value
                        color: Theme.statusOk
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Monospace"
                        Layout.preferredWidth: 120
                    }
                    Text {
                        text: model.rawValue
                        color: Theme.textSecondary
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: historyList.count === 0 && !historyController.isLoading
                text: qsTr("No data.\nAdjust the time range or sensor, then search.")
                color: Theme.textSecondary
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: Math.min(400, parent.width - 32)
            }
        }
    }
}
