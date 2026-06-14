import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DataLogger.Theme

Item {
    id: root

    property string message: ""
    property int iconSize: 48

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width > 0 ? root.width * 0.85 : 320, 400)
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\u2139"
            font.pixelSize: root.iconSize
            color: AppColors.emptyStateIcon
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
