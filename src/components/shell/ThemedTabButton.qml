import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Theme
import DataLogger.Components

// Tab bar button — label and icon use primary text to adhere to Material 3 guidelines
TabButton {
    id: root
    property string iconName: ""
    property int iconSize: 20

    Material.foreground: AppColors.primaryText

    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Rectangle {
        implicitHeight: 40
        color: root.checked ? AppColors.accentContainer
             : root.hovered ? AppColors.hoverFill
             : "transparent"
        radius: Theme.radiusMedium
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: RowLayout {
        spacing: 8
        Layout.alignment: Qt.AlignHCenter

        UiIcon {
            visible: root.iconName !== ""
            name: root.iconName
            size: root.iconSize
            iconColor: root.checked ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font: root.font
            color: root.checked ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
