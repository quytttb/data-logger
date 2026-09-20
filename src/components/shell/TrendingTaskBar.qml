pragma ComponentBehavior: Bound
import QtQuick
import DataLogger.Core
import LoggerKit.Theme

Item {
    id: root
    implicitHeight: 64

    readonly property bool hasSensors: MonitorController.analogSensors
                                       && MonitorController.analogSensors.length > 0

    Item {
        id: legendArea
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        visible: root.hasSensors
        clip: true

        Flow {
            id: legendFlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.min(implicitHeight, 48)
            spacing: 24

            Repeater {
                id: legendRepeater
                model: MonitorController.analogSensors

                delegate: Row {
                    id: chip
                    spacing: 8
                    height: 20
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

        // The header fits two legend rows. Mask a third row with an explicit
        // ellipsis instead of allowing the title bar to grow or scroll.
        Rectangle {
            id: overflowMask
            visible: legendFlow.implicitHeight > 48
            anchors.right: parent.right
            anchors.bottom: legendFlow.bottom
            width: overflowText.implicitWidth + 12
            height: 20
            color: AppColors.surface

            Text {
                id: overflowText
                anchors.centerIn: parent
                text: "..."
                color: AppColors.primaryText
                font.pixelSize: AppTypography.bodySmall.pixelSize
                font.bold: true
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
