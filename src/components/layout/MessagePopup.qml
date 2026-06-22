import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

Popup {
    id: root

    property string popupTitle: ""
    property string popupMessage: ""

    property bool isConfirmMode: false
    property string confirmButtonText: "Confirm"
    property string cancelButtonText: "Cancel"
    property var confirmCallback: null
    property color confirmButtonColor: Theme.btnStart

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent.width - 32)
    padding: Theme.spacingM
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
        confirmButtonColor = okColor || Theme.btnStart
        open()
    }

    background: Rectangle {
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: root.isConfirmMode && root.confirmButtonColor === Theme.btnStop ? Theme.borderErr : Theme.accent
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacingSM

        Text {
            text: root.popupTitle
            font.bold: true
            font.pixelSize: AppTypography.titleLarge.pixelSize
            color: root.isConfirmMode && root.confirmButtonColor === Theme.btnStop ? Theme.statusErr : Theme.textPrimary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.popupMessage
            wrapMode: Text.WordWrap
            color: Theme.accentText
            font.pixelSize: AppTypography.bodyMedium.pixelSize
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        AppButton {
            visible: !root.isConfirmMode
            text: "Close"
            variant: "tonal"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }

        RowLayout {
            visible: root.isConfirmMode
            Layout.fillWidth: true
            spacing: Theme.spacingS

            AppButton {
                text: root.cancelButtonText
                variant: "tonal"
                Layout.fillWidth: true
                onClicked: root.close()
            }

            AppButton {
                text: root.confirmButtonText
                font.bold: true
                Layout.fillWidth: true
                accent: root.confirmButtonColor
                onClicked: {
                    if (root.confirmCallback) root.confirmCallback()
                    root.close()
                }
            }
        }
    }
}
