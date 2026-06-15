pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

Rectangle {
    id: monitorRoot
    color: "transparent"

    // Helper to pass DI states to Repeater (avoids model shadowing in delegate)
    function getDisForDelegate(diStates) {
        return diStates && diStates.length > 0 ? diStates : []
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // ── Sensor Cards Grid (centered) ─────────────────────────────
        GridView {
            id: sensorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 240
            cellHeight: 150
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: MonitorModel
            visible: count > 0

            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
            leftMargin: Math.max(0, Math.floor((width - columns * cellWidth) / 2))

            delegate: Item {
                id: card
                implicitWidth: sensorGrid.cellWidth
                implicitHeight: sensorGrid.cellHeight

                required property string name
                required property string status
                required property string value
                required property string rawValue
                required property string unit
                required property string lastUpdate
                required property bool   isAlarm
                required property string alarmType
                required property string sensorType
                required property var    diStates

                readonly property bool isAnalog: card.sensorType === "ANALOG"
                readonly property bool isDI: card.sensorType === "DI"
                readonly property bool isDO: card.sensorType === "DO"

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Theme.radiusCard
                    color: Theme.bgPanel
                    border.color: {
                        if (card.isAlarm) return Theme.statusErr;
                        if (card.status === "OK" || card.status === "ON") return Theme.borderOk;
                        if (card.status === "ERR") return Theme.borderErr;
                        if (card.isDI && card.value === "1") return "#42A5F5";
                        return Theme.borderDefault;
                    }
                    border.width: {
                        if (card.isAlarm) return 3;
                        if (card.status === "OK" || card.status === "ON") return 2;
                        return 1;
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        // ── Header Row ──────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                visible: !card.isAnalog
                                implicitWidth: 36; implicitHeight: 18; radius: 4
                                color: card.isDI ? "#1E88E5" : "#C62828"
                                Text {
                                    anchors.centerIn: parent
                                    text: card.isDI ? "DI" : "DO"
                                    color: "#FFFFFF"; font.bold: true; font.pixelSize: 10
                                }
                            }

                            StatusChip {
                                visible: card.isAnalog && card.status.length > 0
                                displayStatus: card.status
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                visible: card.isAnalog && card.status.length === 0
                                implicitWidth: 10; implicitHeight: 10; radius: 5
                                color: card.isAlarm ? Theme.statusErr : Theme.textSecondary
                            }

                            Text {
                                text: card.name
                                color: Theme.accentText
                                font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: card.isAlarm && card.isAnalog
                                color: Theme.statusErr
                                radius: 4
                                implicitWidth: alarmLabel.implicitWidth + 8
                                implicitHeight: alarmLabel.implicitHeight + 4
                                Text {
                                    id: alarmLabel
                                    anchors.centerIn: parent
                                    text: card.alarmType === "min" ? "▼ MIN"
                                        : (card.alarmType === "max" ? "▲ MAX" : "ALARM")
                                    color: "#FFFFFF"
                                    font.pixelSize: 9; font.bold: true
                                }
                            }

                            Text {
                                visible: card.isAnalog
                                text: card.unit
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 13; font.bold: true
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.NoWrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }

                        // ── Center Content ───────────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                visible: card.isAnalog
                                anchors.centerIn: parent
                                text: card.value
                                color: card.isAlarm ? Theme.statusErr
                                     : (card.status === "ERR" ? Theme.statusErr : Theme.textPrimary)
                                font.pixelSize: card.value === "---" ? 28 : 36
                                font.family: "Monospace"
                                font.bold: true
                            }

                            Column {
                                visible: card.isDI
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 48; radius: 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? "#1565C0" : "#616161"
                                    border.color: card.value === "1" ? "#42A5F5" : "#9E9E9E"
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? "ON" : "OFF"
                                        color: "#FFFFFF"; font.pixelSize: 13; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? "INPUT ON" : "INPUT OFF"
                                    color: card.value === "1" ? "#42A5F5" : Theme.textSecondary
                                    font.pixelSize: 11; font.bold: true
                                }
                            }

                            Column {
                                visible: card.isDO
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 48; radius: 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? "#C62828" : "#616161"
                                    border.color: card.value === "1" ? "#EF5350" : "#9E9E9E"
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? "ON" : "OFF"
                                        color: "#FFFFFF"; font.pixelSize: 13; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? "RELAY ON" : "RELAY OFF"
                                    color: card.value === "1" ? "#EF5350" : Theme.textSecondary
                                    font.pixelSize: 11; font.bold: true
                                }
                            }
                        }

                        // ── Footer Row ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                visible: card.isAnalog
                                text: (card.rawValue !== "" && card.rawValue !== "---") ? "RAW " + card.rawValue : ""
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 10; font.family: "Monospace"
                            }

                            Row {
                                spacing: 4
                                visible: card.isAnalog && card.diStates && card.diStates.length > 0
                                Layout.leftMargin: 6

                                Repeater {
                                    model: monitorRoot.getDisForDelegate(card.diStates)
                                    Rectangle {
                                        required property var modelData
                                        implicitWidth: 10; implicitHeight: 10; radius: 5
                                        color: modelData.color || "#888888"
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: card.lastUpdate || ""
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }

        EmptyStatePlaceholder {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sensorGrid.count === 0
            message: "No active sensors.\nOpen Settings to add sensors, then press Start monitoring."
            iconName: "chip"
        }
    }
}
