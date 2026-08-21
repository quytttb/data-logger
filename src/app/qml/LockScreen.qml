import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import DataLogger.Theme
import DataLogger.Components

ApplicationWindow {
    visible: true
    visibility: Window.FullScreen
    color: AppColors.surface
    title: "Data Logger"

    Material.theme: AppTheme.materialTheme
    Material.primary: AppTheme.primary
    Material.accent: AppTheme.accent

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingSM

        EmptyStatePlaceholder {
            Layout.preferredWidth: Math.min(parent.width * 0.85, 400)
            iconName: "warning"
            iconSize: 64
            message: "This device is not authorized.\nPlease contact your supplier."
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            // qmllint disable unqualified
            text: "Device ID: " + deviceStationCode
            // qmllint enable unqualified
            font: AppTypography.labelSmall
            color: AppColors.textSoft
        }
    }
}
