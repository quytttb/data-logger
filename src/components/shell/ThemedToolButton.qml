import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Theme
import DataLogger.Components

// Flat tool button — text and icon use buttonText (black in dark mode).
ToolButton {
    id: root
    property string iconName: ""
    property int iconSize: 18

    implicitWidth: text === "" ? 44 : implicitContentWidth + leftPadding + rightPadding
    implicitHeight: text === "" ? 44 : implicitContentHeight + topPadding + bottomPadding

    padding: text === "" ? 0 : 12
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    Material.foreground: AppColors.buttonText

    background: Rectangle {
        anchors.fill: parent
        color: root.down || root.hovered ? AppColors.hoverFill : "transparent"
        border.color: Theme.borderDefault
        border.width: 1
        radius: Theme.radiusMedium
    }

    contentItem: Item {
        RowLayout {
            anchors.centerIn: parent
            spacing: 4

            UiIcon {
                visible: root.iconName !== ""
                name: root.iconName
                size: root.iconSize
                iconColor: root.enabled ? AppColors.buttonText : AppColors.disabledContent
            }

            Text {
                visible: root.text !== ""
                text: root.text
                font: root.font
                color: root.enabled ? AppColors.buttonText : AppColors.disabledContent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
