pragma ComponentBehavior: Bound
import QtQuick
import DataLogger.Core
import LoggerKit.Theme

Item {
    id: root
    implicitHeight: 64

    readonly property bool hasSensors: MonitorController.analogSensors
                                       && MonitorController.analogSensors.length > 0

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
                model: MonitorController.analogSensors

                delegate: Row {
                    id: chip
                    spacing: 8
                    height: legendRow.height
                    required property var modelData

                    Rectangle {
                        width: 12
                        height: 12
                        radius: width / 2
                        color: chip.modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.unit && chip.modelData.unit.length > 0
                              ? (chip.modelData.name + " (" + chip.modelData.unit + ")")
                              : chip.modelData.name
                        color: AppColors.primaryText
                        font.pixelSize: AppTypography.bodySmall.pixelSize
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
        text: qsTr("No active sensors")
        color: AppColors.onSurfaceVariant
        font.pixelSize: AppTypography.bodySmall.pixelSize
        font.italic: true
    }
}
