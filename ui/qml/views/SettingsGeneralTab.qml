import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Item {
    id: root
    property bool configChanged: false

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formContent.implicitHeight + 40
        clip: true; boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            width: flick.width; height: flick.contentHeight
            color: Theme.bgPanel; radius: Theme.radiusCard
            border.color: Theme.borderDefault; border.width: 1

            RowLayout {
                id: formContent
                anchors.fill: parent; anchors.margins: 20
                spacing: 25

                // ── COLUMN 1: Device Information ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Device Information"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Device ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.stationCode : ""
                        onTextEdited: { settingsController.stationCode = text; root.configChanged = true }
                    }

                    Text { text: "Name Device:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.stationName : ""
                        onTextEdited: { settingsController.stationName = text; root.configChanged = true }
                    }

                    Text { text: "Poll interval (s):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    SpinBox {
                        from: 1; to: 3600; Layout.fillWidth: true
                        value: settingsController ? settingsController.pollInterval : 3
                        onValueModified: { settingsController.pollInterval = value; root.configChanged = true }
                    }
                }

                // ── COLUMN 2: Date & Time ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Date & Time"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Time format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["HH:mm:ss", "hh:mm:ss AP"]
                        currentIndex: {
                            var fmt = settingsController ? settingsController.timeFormat : "HH:mm:ss"
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { settingsController.timeFormat = currentText; root.configChanged = true }
                    }

                    Text { text: "Date format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy"]
                        currentIndex: {
                            var fmt = settingsController ? settingsController.dateFormat : "dd/MM/yyyy"
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { settingsController.dateFormat = currentText; root.configChanged = true }
                    }

                    Text { text: "Timezone:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: [
                            "UTC-12", "UTC-11", "UTC-10", "UTC-9", "UTC-8", "UTC-7", "UTC-6", "UTC-5",
                            "UTC-4", "UTC-3", "UTC-2", "UTC-1", "UTC+0", "UTC+1", "UTC+2", "UTC+3",
                            "UTC+4", "UTC+5", "UTC+5:30", "UTC+6", "UTC+7", "UTC+8", "UTC+9", "UTC+10",
                            "UTC+11", "UTC+12"
                        ]
                        currentIndex: {
                            var tz = settingsController ? settingsController.timezone : "UTC+7"
                            return Math.max(0, model.indexOf(tz))
                        }
                        onActivated: { settingsController.timezone = currentText; root.configChanged = true }
                    }

                    Text { text: "Auto sync time:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    Switch {
                        checked: settingsController ? settingsController.autoSyncTime : false
                        onToggled: { settingsController.autoSyncTime = checked; root.configChanged = true }
                    }
                }
            }
        }
    }
}
