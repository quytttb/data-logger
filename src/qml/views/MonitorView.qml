import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Rectangle {
    id: monitorRoot
    color: "transparent"

    // Helper to pass DI states to Repeater (avoids model shadowing in delegate)
    function getDisForDelegate(diStates) {
        return diStates && diStates.length > 0 ? diStates : []
    }

    MessagePopup {
        id: monitorPopup
    }

    Connections {
        target: monitorController
        function onMessageSent(t, m) { monitorPopup.showMessage(t, m) }
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
            model: monitorModel

            // Center the grid: compute how many columns fit, then pad
            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
            leftMargin: Math.max(0, Math.floor((width - columns * cellWidth) / 2))

            delegate: Item {
                width: sensorGrid.cellWidth
                height: sensorGrid.cellHeight

                // Convenience properties at delegate scope
                readonly property string sType: model.sensorType || "ANALOG"
                readonly property bool isAnalog: sType === "ANALOG"
                readonly property bool isDI: sType === "DI"
                readonly property bool isDO: sType === "DO"

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: Theme.radiusCard
                    color: Theme.bgPanel
                    border.color: {
                        if (model.isAlarm)  return Theme.statusErr;
                        if (model.status === "OK" || model.status === "ON")  return Theme.borderOk;
                        if (model.status === "ERR") return Theme.borderErr;
                        // DI active state
                        if (isDI && model.value === "1") return "#42A5F5";
                        return Theme.borderDefault;
                    }
                    border.width: {
                        if (model.isAlarm) return 3;
                        if (model.status === "OK" || model.status === "ON") return 2;
                        return 1;
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        // ── Header Row: status dot + name + badge/unit ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Type badge for DI/DO
                            Rectangle {
                                visible: !isAnalog
                                width: 36; height: 18; radius: 4
                                color: isDI ? "#1E88E5" : "#C62828"
                                Text {
                                    anchors.centerIn: parent
                                    text: isDI ? "DI" : "DO"
                                    color: "#FFFFFF"; font.bold: true; font.pixelSize: 10
                                }
                            }

                            Rectangle {
                                visible: isAnalog
                                width: 10; height: 10; radius: 5
                                color: {
                                    if (model.isAlarm)  return Theme.statusErr;
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

                            // Alarm badge (ANALOG only)
                            Rectangle {
                                visible: model.isAlarm && isAnalog
                                color: Theme.statusErr
                                radius: 4
                                implicitWidth: alarmLabel.implicitWidth + 8
                                implicitHeight: alarmLabel.implicitHeight + 4
                                Text {
                                    id: alarmLabel
                                    anchors.centerIn: parent
                                    text: model.alarmType === "min" ? "▼ MIN"
                                        : (model.alarmType === "max" ? "▲ MAX" : "ALARM")
                                    color: "#FFFFFF"
                                    font.pixelSize: 9; font.bold: true
                                }
                            }

                            Text {
                                visible: isAnalog
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

                        // ── Center Content: value / indicator / toggle ──
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // ANALOG: Large numeric value
                            Text {
                                visible: isAnalog
                                anchors.centerIn: parent
                                text: model.value
                                color: model.isAlarm ? Theme.statusErr
                                     : (model.status === "ERR" ? Theme.statusErr : Theme.textPrimary)
                                font.pixelSize: model.value === "---" ? 28 : 36
                                font.family: "Monospace"
                                font.bold: true
                            }

                            // DI: Large status indicator circle
                            Column {
                                visible: isDI
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 48; height: 48; radius: 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: model.value === "1" ? "#1565C0" : "#616161"
                                    border.color: model.value === "1" ? "#42A5F5" : "#9E9E9E"
                                    border.width: 3

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.value === "1" ? "ON" : "OFF"
                                        color: "#FFFFFF"
                                        font.pixelSize: 13; font.bold: true
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: model.value === "1" ? "INPUT ON" : "INPUT OFF"
                                    color: model.value === "1" ? "#42A5F5" : Theme.textSecondary
                                    font.pixelSize: 11; font.bold: true
                                }
                            }

                            // DO: Simple ON/OFF status indicator (relay state)
                            Column {
                                visible: isDO
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    width: 48; height: 48; radius: 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: model.value === "1" ? "#C62828" : "#616161"
                                    border.color: model.value === "1" ? "#EF5350" : "#9E9E9E"
                                    border.width: 3

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.value === "1" ? "ON" : "OFF"
                                        color: "#FFFFFF"
                                        font.pixelSize: 13; font.bold: true
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: model.value === "1" ? "RELAY ON" : "RELAY OFF"
                                    color: model.value === "1" ? "#EF5350" : Theme.textSecondary
                                    font.pixelSize: 11; font.bold: true
                                }
                            }
                        }

                        // ── Footer Row: raw value + DI dots + timestamp ──
                        RowLayout {
                            Layout.fillWidth: true

                            // Raw value (ANALOG only)
                            Text {
                                visible: isAnalog
                                text: (model.rawValue && model.rawValue !== "---") ? "RAW " + model.rawValue : ""
                                color: Theme.textOnColoredBtn
                                font.pixelSize: 10
                                font.family: "Monospace"
                            }


                            // DI indicator dots — only active DIs shown (ANALOG only)
                            Row {
                                spacing: 4
                                visible: isAnalog && model.diStates && model.diStates.length > 0
                                Layout.leftMargin: 6

                                Repeater {
                                    model: monitorRoot.getDisForDelegate(diStates)

                                    Rectangle {
                                        width: 10; height: 10; radius: 5
                                        color: modelData.color || "#888888"
                                    }
                                }

                                // Alias to resolve model.diStates at delegate scope
                                property var diStates: model.diStates || []
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
