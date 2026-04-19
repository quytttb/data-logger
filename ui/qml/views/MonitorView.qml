import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Rectangle {
    id: monitorRoot
    color: "transparent"

    MessagePopup {
        id: monitorPopup
        parent: monitorRoot
    }

    Connections {
        target: monitorController
        function onMessageSent(t, m) { monitorPopup.showMessage(t, m) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Điều khiển + trạng thái nằm trên header (DashboardTaskBar.qml trong Main).

        // ── Sensor Cards Grid (centered) ─────────────────────────────
        GridView {
            id: sensorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 240
            cellHeight: 150
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: monitorModel

            // Center the grid: compute how many columns fit, then pad
            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
            leftMargin: Math.max(0, Math.floor((width - columns * cellWidth) / 2))

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

                            Text {
                                text: model.unit
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 13; font.bold: true
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.NoWrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
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
                                text: (model.rawValue && model.rawValue !== "---") ? "RAW " + model.rawValue : ""
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 10
                                font.family: "Monospace"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: model.lastUpdate || ""
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.fillHeight: true
            visible: sensorGrid.count === 0
            text: "No active sensors.\nOpen Settings to add sensors, then press Start monitoring."
            color: Theme.textSecondary
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
