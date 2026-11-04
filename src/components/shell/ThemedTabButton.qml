pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

// Tab bar button — label and icon use primary text to adhere to Material 3 guidelines
TabButton {
    id: root
    property string iconName: ""
    property string iconGlyph: ""
    property bool iconOnly: false
    property int iconSize: 20

    Material.foreground: AppColors.primaryText
    Accessible.name: root.text
    ToolTip.visible: root.iconOnly && root.hovered
    ToolTip.text: root.text

    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    background: Rectangle {
        implicitHeight: AppTheme.buttonHeight
        color: root.checked ? AppColors.accentContainer
             : root.hovered ? AppColors.hoverFill
             : "transparent"
        radius: AppTheme.listItemRadius
        
        Behavior on color {
            ColorAnimation { duration: AppTheme.motionStandard }
        }
    }

    contentItem: RowLayout {
        spacing: 8
        Layout.alignment: Qt.AlignHCenter

        UiIcon {
            visible: root.iconName !== "" || root.iconGlyph !== ""
            name: root.iconName
            text: root.iconGlyph !== "" ? root.iconGlyph : MaterialIcons.glyph(root.iconName)
            size: root.iconSize
            iconColor: root.checked ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: !root.iconOnly && root.text !== ""
            text: root.text
            font: root.font
            color: root.checked ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
