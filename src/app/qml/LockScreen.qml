import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import DataLogger.Components
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
        spacing: AppTheme.spacingSM

        EmptyStatePlaceholder {
            Layout.preferredWidth: Math.min(parent.width * 0.85, 400)
            iconName: "warning"
            iconSize: 64
            message: "This device is not authorized.\nPlease contact your supplier."
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            // qmllint disable unqualified
            text: qsTr("Device ID: ") + deviceStationCode
            // qmllint enable unqualified
            font: AppTypography.labelSmall
            color: AppColors.textSoft
        }
    }
}
