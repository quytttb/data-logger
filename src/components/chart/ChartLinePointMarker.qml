import QtQuick

import DataLogger.Theme

Item {
    id: root

    width: 12
    height: 12

    property color pointColor: AppColors.primaryText
    property bool active: false

    Rectangle {
        anchors.centerIn: parent
        width: root.active ? 8 : 6
        height: width
        radius: width / 2
        color: AppColors.surfaceContainerHigh
        border.width: 2
        border.color: root.pointColor
    }
}
