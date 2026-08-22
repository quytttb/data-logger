import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LoggerKit.Theme
import LoggerKit.Components

Popup {
    id: root

    property string popupTitle: ""
    property string popupMessage: ""

    property bool isConfirmMode: false
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    property var confirmCallback: null
    property color confirmButtonColor: AppColors.success

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent.width - 32)
    padding: AppTheme.spacingM
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function showMessage(t, m) {
        isConfirmMode = false
        popupTitle = t
        popupMessage = m
        open()
    }

    function showConfirm(t, m, onConfirm, okText, okColor) {
        isConfirmMode = true
        popupTitle = t
        popupMessage = m
        confirmCallback = onConfirm
        confirmButtonText = okText || "Confirm"
        confirmButtonColor = okColor || AppColors.success
        open()
    }

    background: Rectangle {
        color: AppColors.surfaceContainerLow
        radius: AppTheme.cardRadius
        border.color: root.isConfirmMode && root.confirmButtonColor === AppColors.error ? AppColors.error : AppColors.primaryColor
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: AppTheme.spacingSM

        Text {
            text: root.popupTitle
            font.bold: true
            font.pixelSize: AppTypography.titleLarge.pixelSize
            color: root.isConfirmMode && root.confirmButtonColor === AppColors.error ? AppColors.error : AppColors.primaryText
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.popupMessage
            wrapMode: Text.WordWrap
            color: AppColors.accentColor
            font.pixelSize: AppTypography.bodyMedium.pixelSize
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        AppButton {
            visible: !root.isConfirmMode
            text: qsTr("Close")
            kind: AppButton.Neutral
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }

        RowLayout {
            visible: root.isConfirmMode
            Layout.fillWidth: true
            spacing: AppTheme.spacingS

            AppButton {
                text: root.cancelButtonText
                kind: AppButton.Neutral
                Layout.fillWidth: true
                onClicked: root.close()
            }

            AppButton {
                text: root.confirmButtonText
                font.bold: true
                Layout.fillWidth: true
                fillColor: root.confirmButtonColor
                onClicked: {
                    if (root.confirmCallback) root.confirmCallback()
                    root.close()
                }
            }
        }
    }
}
