pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import LoggerKit.Theme
import LoggerKit.Components

ApplicationWindow {
    visible: true
    visibility: Window.FullScreen
    color: AppColors.surface
    title: qsTr("Data Logger")

    Material.theme: AppTheme.materialTheme
    Material.primary: AppTheme.primary
    Material.accent: AppTheme.accent

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.85, 400)
        spacing: AppTheme.spacingSM

        EmptyStatePlaceholder {
            // Chiều cao lấy từ implicitHeight của placeholder (forward từ
            // nội dung bên trong) nên xếp chồng tự nhiên, không tràn/đè.
            Layout.fillWidth: true
            iconName: "warning"
            iconSize: 64
            message: qsTr("This device is not authorized.\nPlease contact your supplier.")
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: AppTheme.spacingS
            // qmllint disable unqualified
            text: qsTr("Device ID: ") + deviceStationCode
            // qmllint enable unqualified
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            elide: Text.ElideMiddle
            font: AppTypography.labelSmall
            color: AppColors.textSoft
        }
    }
}
