import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DataLogger.Theme
import DataLogger.Components

Item {
    id: root

    property string message: ""
    property int iconSize: 48
    property string iconName: "info"

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width > 0 ? root.width * 0.85 : 320, 400)
        spacing: 12

        UiIcon {
            Layout.alignment: Qt.AlignHCenter
            name: root.iconName
            size: root.iconSize
            iconColor: AppColors.emptyStateIcon
        }

        Label {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font: AppTypography.bodyMedium
            color: AppColors.textSoft
        }
    }
}
