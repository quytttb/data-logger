import QtQuick
import QtQuick.Controls
import QtQuick.VirtualKeyboard
import DataLogger.Theme

/** TextField nền Theme.bgInput — dùng trong form; radiusTiny hoặc radiusSmall (date field). */
TextField {
    id: root
    color: Theme.textPrimary
    property bool useSmallRadius: false
    // On-screen keyboard "enter" key reads "OK" (commits and dismisses).
    // actionId None forces the keyboard to show the label instead of an icon.
    EnterKeyAction.actionId: EnterKeyAction.None
    EnterKeyAction.label: qsTr("OK")
    background: Rectangle {
        color: Theme.bgInput
        radius: root.useSmallRadius ? Theme.radiusSmall : Theme.radiusTiny
    }
}
