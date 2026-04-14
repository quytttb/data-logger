import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: dashRoot
    color: "transparent"

    // ── Message Popup ─────────────────────────────────────────────────────
    Popup {
        id: dashPopup
        anchors.centerIn: parent
        width: 340; height: 160
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.bgSeparator; radius: 8
            border.color: Theme.accent; border.width: 2
        }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 15
            Text { id: dashPopTitle; font.bold: true; font.pixelSize: 18; color: Theme.textPrimary; Layout.alignment: Qt.AlignHCenter }
            Text { id: dashPopMsg; wrapMode: Text.WordWrap; color: Theme.accentText; font.pixelSize: 14; Layout.fillWidth: true; Layout.fillHeight: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            Button { text: qsTr("Close"); Layout.alignment: Qt.AlignHCenter; onClicked: dashPopup.close() }
        }
    }

    Connections {
        target: dashboardController
        function onMessageSent(t, m) { dashPopTitle.text = t; dashPopMsg.text = m; dashPopup.open() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Điều khiển + trạng thái nằm trên header (DashboardTaskBar.qml trong Main).

        // ── Sensor Cards Grid ─────────────────────────────────────────────
        GridView {
            id: sensorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 240
            cellHeight: 150
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: dashboardModel

            delegate: Item {
                width: sensorGrid.cellWidth
                height: sensorGrid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Theme.radiusCard
                    color: Theme.bgPanel
                    border.color: {
                        if (model.status === "OK")  return Theme.borderOk;
                        if (model.status === "ERR") return Theme.borderErr;
                        return Theme.borderDefault;
                    }
                    border.width: model.status === "OK" ? 2 : 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: {
                                    if (model.status === "OK")  return Theme.statusOk;
                                    if (model.status === "ERR") return Theme.statusErrBright;
                                    return Theme.textSecondary;
                                }
                            }

                            Text {
                                text: model.name
                                color: Theme.accentText
                                font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.centerIn: parent
                                text: model.value
                                color: model.status === "ERR" ? Theme.statusErr : Theme.textPrimary
                                font.pixelSize: model.value === "---" ? 28 : 36
                                font.family: "Monospace"
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: model.unit
                                color: Theme.textSecondary
                                font.pixelSize: 13; font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (model.rawValue && model.rawValue !== "---") ? "RAW " + model.rawValue : ""
                                color: "#555"
                                font.pixelSize: 10; font.family: "Monospace"
                            }
                            Text {
                                text: model.lastUpdate || ""
                                color: "#666"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: sensorGrid.count === 0
            text: qsTr("No active sensors.\nOpen Settings to add sensors, then press Start acquisition.")
            color: Theme.textSecondary
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
