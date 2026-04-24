import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    property alias listView: sensorListView

    signal sensorDoubleClicked()

    ColumnLayout {
        anchors.fill: parent; spacing: 0
        
        // Header
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Theme.bgSeparator; radius: Theme.radiusTiny
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 5
                Text { text: "Name";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 130 }
                Text { text: "Unit";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50 }
                Text { text: "Slave";    color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Addr";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Reg";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Type";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Format";   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Intv";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Idx";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Thresholds"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Active";   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
            }
        }

        // List
        ListView {
            id: sensorListView
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: sensorModel
            boundsBehavior: Flickable.StopAtBounds
            
            delegate: Rectangle {
                width: sensorListView.width; height: 44
                color: ListView.isCurrentItem ? Theme.bgSeparator : (index % 2 === 0 ? "transparent" : Theme.bgDeep)
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: sensorListView.currentIndex = index
                    onDoubleClicked: root.sensorDoubleClicked()
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 5
                    Text { text: name; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; font.bold: true; Layout.preferredWidth: 130; elide: Text.ElideRight }
                    Text { text: unit; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 50; elide: Text.ElideRight }
                    Text { text: slaveId; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text { text: registerAddress; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text { 
                        text: {
                            var t = String(registerType).toLowerCase().trim()
                            if (t.indexOf("holding") >= 0 || t === "hr") return "HOLD"
                            if (t === "inputs" || t.indexOf("discrete") >= 0 || t === "di") return "DISC"
                            if (t.indexOf("input") >= 0 || t === "ir") return "INPT"
                            if (t.indexOf("coil") >= 0) return "COIL"
                            if (t.indexOf("invalid") >= 0) return "INV"
                            return t.substring(0, 4).toUpperCase()
                        }
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter 
                    }
                    Text { text: dataType; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter }
                    Text { text: dataFormat; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                    Text { text: pollInterval + "s"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text { text: reportIndex; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
                    Text { 
                        text: (minThreshold !== undefined && minThreshold !== "" ? minThreshold : "-") + "  →  " + (maxThreshold !== undefined && maxThreshold !== "" ? maxThreshold : "-")
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        Layout.preferredWidth: 50; Layout.fillHeight: true
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            anchors.centerIn: parent
                            color: active ? Theme.statusOk : Theme.btnStop
                            border.color: Theme.borderDefault; border.width: 1
                        }
                    }
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sensorListView.count === 0
            
            Text {
                anchors.centerIn: parent
                text: "No sensors yet.\nClick [+ Add sensor] to create one."
                color: Theme.textSecondary; font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
