import QtQuick
import QtQuick.VirtualKeyboard

// On-screen keyboard for touch input. Slides up from the bottom whenever a text
// field gains focus and slides back down on blur. With VirtualKeyboardSettings
// fullScreenMode enabled (see Main.qml) the panel also shows a large mirror of
// the focused field's text at its top, so covered fields are never an issue.
InputPanel {
    id: inputPanel
    z: 999

    // The ApplicationWindow that drives the keyboard geometry. Typed as var
    // because ApplicationWindow is a Window, not an Item.
    property var window: null

    width: window ? window.width : 0
    x: 0
    y: window ? window.height : 0

    states: State {
        name: "visible"
        when: inputPanel.active
        PropertyChanges {
            target: inputPanel
            y: (inputPanel.window ? inputPanel.window.height : 0) - inputPanel.height
        }
    }
    transitions: Transition {
        from: ""
        to: "visible"
        reversible: true
        NumberAnimation {
            properties: "y"
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }
}
