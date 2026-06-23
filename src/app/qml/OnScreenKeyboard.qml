import QtQuick
import QtQuick.VirtualKeyboard

// On-screen keyboard for touch input.
//
// For VirtualKeyboardSettings.fullScreenMode (enabled in Main.qml) to work the
// InputPanel MUST be free to use the whole window: it draws a dimmed backdrop
// plus a large mirror of the focused field at the top and the keys at the
// bottom. Squeezing it to a bottom strip (manual y/height) silently disables
// fullscreen rendering, so we fill the parent and just toggle visibility.
InputPanel {
    id: inputPanel
    z: 999
    anchors.fill: parent
    visible: active
}
