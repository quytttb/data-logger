import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

/**
 * Hộp thoại thông báo modal (lỗi / info) — dùng chung Monitor, History, Settings.
 * compact: kiểu Settings (340×160, chữ căn giữa); mặc định: rộng theo parent, nội dung trái.
 */
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
    padding: 18
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
        border.color: isConfirmMode && confirmButtonColor === Theme.btnStop ? Theme.borderErr : Theme.accent
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: root.popupTitle
            font.bold: true
            font.pixelSize: 18
            color: isConfirmMode && confirmButtonColor === Theme.btnStop ? Theme.statusErr : Theme.textPrimary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.popupMessage
            wrapMode: Text.WordWrap
            color: Theme.accentText
            font.pixelSize: 14
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // ── Single "Close" button for info mode ──
        Button {
            visible: !root.isConfirmMode
            text: "Close"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }

        // ── Action buttons for confirm mode ──
        RowLayout {
            visible: root.isConfirmMode
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: root.cancelButtonText
                Layout.fillWidth: true
                onClicked: root.close()
            }

            Button {
                text: root.confirmButtonText
                Layout.fillWidth: true
                background: Rectangle {
                    color: root.confirmButtonColor
                    radius: Theme.radiusSmall
                    opacity: parent.pressed ? 0.7 : 1.0
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textOnColoredBtn
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (root.confirmCallback) root.confirmCallback()
                    root.close()
                }
            }
        }
    }
}
