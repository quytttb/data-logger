import QtQuick
import QtQuick.VirtualKeyboard

// On-screen keyboard for touch input. Slides up from the bottom whenever a text
// field gains focus and slides back down on blur. It also keeps the focused
// field visible by shifting `avoidTarget` upward when the keyboard would cover
// it (Qt Virtual Keyboard does not scroll the focused control into view itself).
InputPanel {
    id: inputPanel
    z: 999

    // The ApplicationWindow whose geometry/active-focus drives the keyboard
    // placement. Typed as var because ApplicationWindow is a Window, not an Item.
    property var window: null
    // The content item to shift up so the focused field stays above the keyboard.
    property Item avoidTarget: null
    // Gap left between the focused field and the top edge of the keyboard.
    property real avoidMargin: 12

    readonly property Item focusItem: window ? window.activeFocusItem : null

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

    function recomputeAvoidance() {
        if (!avoidTarget || !window)
            return
        if (!active || !focusItem) {
            avoidTarget.y = 0
            return
        }
        var ref = window.contentItem ? window.contentItem : window
        var keyboardTop = window.height - height
        var visibleBottom = keyboardTop - avoidMargin
        // Bottom of the focused field in content-item coordinates (already
        // includes any shift currently applied to avoidTarget).
        var fieldBottom = focusItem.mapToItem(ref, 0, focusItem.height).y
        if (fieldBottom > visibleBottom)
            avoidTarget.y -= (fieldBottom - visibleBottom)
    }

    onActiveChanged: recomputeAvoidance()
    onHeightChanged: recomputeAvoidance()
    onFocusItemChanged: recomputeAvoidance()
}
