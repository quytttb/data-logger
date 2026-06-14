import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

// TAB 1: Scaling & Alarms
Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    // ── Expose form fields ──
    property alias dMinThreshold: dMinThreshold
    property alias dMaxThreshold: dMaxThreshold
    property alias dScalingMode: dScalingMode
    property alias dLinearA: dLinearA
    property alias dLinearB: dLinearB
    property alias dRawMin: dRawMin
    property alias dRawMax: dRawMax
    property alias dScaleMin: dScaleMin
    property alias dScaleMax: dScaleMax
    property alias dCoeffJson: dCoeffJson

    ColumnLayout {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 20
        spacing: 8

        Text { text: "Scaling & Alarms"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

        // Use a 2-column grid for compact threshold + scaling layout
        GridLayout {
            columns: 4; Layout.fillWidth: true; columnSpacing: 15; rowSpacing: 8

            Text { text: "Min threshold:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            TextField { id: dMinThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
            Text { text: "Max threshold:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            TextField { id: dMaxThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
        }

        Item { Layout.preferredHeight: 8 }

        Text { text: "Scaling mode:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
        ComboBox {
            id: dScalingMode; Layout.fillWidth: true; Layout.maximumWidth: 400
            model: ["No scaling (raw value)", "Linear (y = ax + b)", "Two-point mapping", "Advanced (JSON)"]
        }

        StackLayout {
            Layout.fillWidth: true; currentIndex: dScalingMode.currentIndex
            Item { implicitHeight: 0 }
            RowLayout {
                spacing: 8
                Text { text: "a:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                TextField { id: dLinearA; Layout.fillWidth: true; text: "1" }
                Text { text: "b:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                TextField { id: dLinearB; Layout.fillWidth: true; text: "0" }
            }
            ColumnLayout {
                spacing: 6
                RowLayout {
                    spacing: 8
                    Text { text: "RawMin:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 60 }
                    TextField { id: dRawMin; text: "4000"; Layout.fillWidth: true }
                    Text { text: "Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField { id: dRawMax; text: "20000"; Layout.fillWidth: true }
                }
                RowLayout {
                    spacing: 8
                    Text { text: "ScaleMin:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 60 }
                    TextField { id: dScaleMin; text: "4"; Layout.fillWidth: true }
                    Text { text: "Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField { id: dScaleMax; text: "20"; Layout.fillWidth: true }
                }
            }
            TextField { id: dCoeffJson; text: "{}"; Layout.fillWidth: true }
        }
    }
}
