pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Theme

Pane {
    id: root

    property string semantic: "error"
    property string message: ""
    property bool dismissible: false

    signal dismissed()

    Material.elevation: 0
    padding: dismissible ? 8 : 12

    background: Rectangle {
        radius: AppTheme.cardRadius
        color: root.semantic === "warning"
               ? AppColors.warningContainer
               : AppColors.errorContainer
        border.width: 1
        border.color: root.semantic === "warning"
                        ? AppColors.warning
                        : AppColors.outlineVariant
    }

    contentItem: RowLayout {
        spacing: AppTheme.toolbarGap

        Label {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.WordWrap
            color: root.semantic === "warning"
                   ? AppColors.primaryText
                   : AppColors.errorContainerFg
            font: root.semantic === "warning" ? AppTypography.bodyMedium : AppTypography.labelMedium
        }

        Label {
            visible: root.dismissible
            text: "\u2715"
            color: AppColors.error
            font.pixelSize: 16

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.dismissed()
                    root.visible = false
                }
            }
        }
    }
}
