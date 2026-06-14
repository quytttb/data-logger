pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    property alias listView: sensorListView

    signal sensorDoubleClicked()

    onVisibleChanged: {
        if (visible) {
            sensorListView.currentIndex = -1
        }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.bgSeparator; radius: Theme.radiusTiny
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 5
                Text { text: "Name";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 120 }
                Text { text: "Unit";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50 }
                Text { text: "Slave";    color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Addr";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Reg";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Type";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Format";   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Intv";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Thresholds"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: "Active";   color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
            }
        }

        ListView {
            id: sensorListView
            clip: true
            smooth: false
            Layout.fillWidth: true; Layout.fillHeight: true
            model: SensorListModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: sensorRow
                required property int index
                required property string name
                required property string unit
                required property int slaveId
                required property int registerAddress
                required property string registerType
                required property string dataType
                required property string dataFormat
                required property var minThreshold
                required property var maxThreshold
                required property int pollInterval
                required property bool active

                width: ListView.view.width; height: 44
                color: sensorRow.index % 2 === 0 ? "transparent" : Theme.bgDeep
                border.color: ListView.isCurrentItem ? Theme.accent : "transparent"
                border.width: ListView.isCurrentItem ? 2 : 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        ListView.view.currentIndex = (ListView.view.currentIndex === sensorRow.index) ? -1 : sensorRow.index
                    }
                    onDoubleClicked: root.sensorDoubleClicked()
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 5
                    Text { text: sensorRow.name; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; font.bold: true; Layout.preferredWidth: 120; elide: Text.ElideRight }
                    Text { text: sensorRow.unit; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 50; elide: Text.ElideRight }
                    Text { text: sensorRow.slaveId; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text { text: sensorRow.registerAddress; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text {
                        text: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            if (t.indexOf("holding") >= 0 || t === "hr") return "HOLD"
                            if (t === "inputs" || t.indexOf("discrete") >= 0 || t === "di") return "DISC"
                            if (t.indexOf("input") >= 0 || t === "ir") return "INPT"
                            if (t.indexOf("coil") >= 0) return "COIL"
                            if (t.indexOf("invalid") >= 0) return "INV"
                            return t.substring(0, 4).toUpperCase()
                        }
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : sensorRow.dataType
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : sensorRow.dataFormat
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : (sensorRow.pollInterval + "s")
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            var isBool = t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                            if (isBool) return ""
                            return (sensorRow.minThreshold !== undefined && sensorRow.minThreshold !== "" ? sensorRow.minThreshold : "-") + "  →  " + (sensorRow.maxThreshold !== undefined && sensorRow.maxThreshold !== "" ? sensorRow.maxThreshold : "-")
                        }
                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        Layout.preferredWidth: 50; Layout.fillHeight: true
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            anchors.centerIn: parent
                            color: sensorRow.active ? Theme.statusOk : Theme.btnStop
                            border.color: Theme.borderDefault; border.width: 1
                        }
                    }
                }
            }
        }

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
