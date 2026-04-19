import QtQuick
import QtQuick.Controls
import ".."

/** TextField nền Theme.bgInput — dùng trong form; radiusTiny hoặc radiusSmall (date field). */
TextField {
    id: root
    color: Theme.textPrimary
    property bool useSmallRadius: false
    background: Rectangle {
        color: Theme.bgInput
        radius: root.useSmallRadius ? Theme.radiusSmall : Theme.radiusTiny
    }
}
