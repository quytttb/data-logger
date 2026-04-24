import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

/**
 * Hộp thoại thông báo dạng Toast (không modal, tự động ẩn sau 2.8s)
 */
Popup {
    id: root
    
    property string toastTitle: ""
    property string toastMessage: ""
    property int durationMs: 2800
    
    parent: Overlay.overlay
    modal: false
    focus: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
    width: Overlay.overlay ? Math.min(440, Overlay.overlay.width - 48) : 440
    x: Overlay.overlay ? Overlay.overlay.width - width - 24 : 0
    y: Overlay.overlay ? Overlay.overlay.height - height - 24 : 0
    padding: 12

    function showToast(title, msg) {
        toastTitle = title
        toastMessage = msg
        open()
    }

    background: Rectangle {
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: Theme.statusOk
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 8
        width: root.availableWidth
        Label { 
            text: root.toastTitle
            font.bold: true
            font.pixelSize: 14
            color: Theme.textPrimary
            Layout.fillWidth: true 
        }
        Label { 
            text: root.toastMessage
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: Theme.accentText
            Layout.fillWidth: true 
        }
    }

    Timer { 
        id: toastTimer
        interval: root.durationMs
        repeat: false
        onTriggered: root.close() 
    }
    
    onOpened: toastTimer.restart()
}
