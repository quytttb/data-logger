import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Components
import DataLogger.Theme

Popup {
    id: root

    parent: Overlay.overlay
    padding: 0

    Component.onCompleted: positionToast()
    onVisibleChanged: if (visible) positionToast()

    function positionToast() {
        if (!parent) return
        x = (parent.width - implicitWidth) / 2
        y = parent.height - implicitHeight - 24
    }
    implicitWidth: Math.min(480, parent ? parent.width - 48 : 480)
    implicitHeight: toastBody.implicitHeight + 16

    visible: AppNotifier.toastVisible && !AppNotifier.suppressed
    closePolicy: Popup.NoAutoClose
    Material.elevation: 3

    function semanticIcon(semantic) {
        switch (semantic) {
        case "success": return "checkCircle"
        case "warning": return "warning"
        case "error":   return "error"
        default:        return "info"
        }
    }

    function semanticColor(semantic) {
        switch (semantic) {
        case "success": return AppColors.success
        case "warning": return AppColors.warning
        case "error":   return AppColors.error
        default:        return AppColors.info
        }
    }

    Timer {
        running: root.visible
        interval: AppNotifier.toastDurationMs
        onTriggered: AppNotifier.dismiss()
    }

    background: Rectangle {
        color: AppColors.surfaceContainerHigh
        radius: AppTheme.cardRadius
        border.width: 1
        border.color: AppColors.elevatedBorder
    }

    contentItem: Item {
        id: toastBody
        implicitWidth:  contentRow.implicitWidth + 32
        implicitHeight: contentRow.implicitHeight + 16

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (AppNotifier.pendingDetailText.length > 0) {
                    AppNotifier.openDetail(
                        AppNotifier.pendingDetailTitle,
                        AppNotifier.pendingDetailText
                    )
                }
                AppNotifier.dismiss()
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: Theme.spacingS

            UiIcon {
                name: root.semanticIcon(AppNotifier.toastSemantic)
                iconColor: root.semanticColor(AppNotifier.toastSemantic)
                size: AppTheme.iconSizeSm
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: AppNotifier.toastSummary
                color: AppColors.primaryText
                font: AppTypography.bodyMedium
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            Text {
                visible: AppNotifier.pendingDetailText.length > 0
                text: qsTr("Details")
                color: AppColors.primaryColor
                font: AppTypography.labelLarge
            }

            UiIcon {
                name: "close"
                iconColor: AppColors.textMuted
                size: AppTheme.iconSizeSm
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        AppNotifier.dismiss()
                    }
                }
            }
        }
    }
}
