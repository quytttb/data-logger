import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * Hộp thoại thông báo modal (lỗi / info) — dùng chung Monitor, History, Settings.
 * compact: kiểu Settings (340×160, chữ căn giữa); mặc định: rộng theo parent, nội dung trái.
 */
Popup {
    id: root

    property bool compact: false
    property string popupTitle: ""
    property string popupMessage: ""

    anchors.centerIn: parent
    width: compact ? 340 : Math.min(440, parent.width - 32)
    padding: 0
    height: compact ? 160 : implicitHeight
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function showMessage(t, m) {
        popupTitle = t
        popupMessage = m
        open()
    }

    background: Rectangle {
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: Theme.accent
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: compact ? 15 : 18
        spacing: 12

        Text {
            text: root.popupTitle
            font.bold: true
            font.pixelSize: compact ? 18 : 17
            color: Theme.textPrimary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: compact ? Text.AlignHCenter : Text.AlignLeft
            Layout.alignment: compact ? Qt.AlignHCenter : Qt.AlignLeft
        }

        Text {
            text: root.popupMessage
            wrapMode: Text.WordWrap
            color: Theme.accentText
            font.pixelSize: 14
            Layout.fillWidth: true
            Layout.fillHeight: compact
            Layout.maximumWidth: compact ? parent.width : undefined
            horizontalAlignment: compact ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: compact ? Text.AlignVCenter : Text.AlignTop
        }

        Button {
            text: "Close"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }
}
