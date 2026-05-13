import QtQuick
import QtQuick.Controls
import ".."

// Chú thích màu cuộn ngang cho Trending
Item {
    id: root
    implicitHeight: 64

    readonly property bool hasSensors: monitorController.analogSensors
                                       && monitorController.analogSensors.length > 0

    Flickable {
        id: legendFlick
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        visible: root.hasSensors
        clip: true
        contentWidth: legendRow.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: legendRow
            spacing: 24
            height: legendFlick.height

            Repeater {
                id: legendRepeater
                model: monitorController.analogSensors

                delegate: Row {
                    id: chip
                    spacing: 8
                    height: legendRow.height
                    required property var modelData

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.unit && modelData.unit.length > 0
                              ? (modelData.name + " (" + modelData.unit + ")")
                              : modelData.name
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }
        }
    }

    Text {
        anchors.fill: parent
        visible: !root.hasSensors
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "No active sensors"
        color: Theme.textSecondary
        font.pixelSize: 13
        font.italic: true
    }
}
