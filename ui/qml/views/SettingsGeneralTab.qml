import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Item {
    id: root
    property bool configChanged: false
    /** Set from SettingsView — shared MessagePopup for firmware confirm. */
    property var settingsMessagePopup: null

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

                // ── COLUMN 1: Device + Firmware ──
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
                        id: pollSpin
                        from: 1; to: 3600; stepSize: 1; Layout.fillWidth: true
                        editable: true
                        validator: IntValidator { bottom: 1; top: 3600 }
                        textFromValue: function(value) { return String(Math.round(value)) }
                        valueFromText: function(text) {
                            var n = parseInt(text, 10)
                            if (isNaN(n)) return 1
                            return Math.min(3600, Math.max(1, n))
                        }
                        value: settingsController ? settingsController.pollInterval : 3
                        Connections {
                            target: settingsController
                            function onConfigLoaded() {
                                pollSpin.value = settingsController.pollInterval
                            }
                        }
                        onValueModified: {
                            settingsController.pollInterval = Math.round(value)
                            root.configChanged = true
                        }
                    }

                    Item { Layout.preferredHeight: 8 }

                    Text { text: "Firmware update"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Button {
                        text: "Check for updates"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        onClicked: {
                            if (settingsMessagePopup) {
                                settingsMessagePopup.showConfirm(
                                    "Firmware update",
                                    "The application will contact GitHub to check for updates. " +
                                    "If a newer build is available, it will be downloaded and applied; the app may restart.\n\nContinue?",
                                    function() { settingsController.checkUpdates() },
                                    "Continue",
                                    Theme.accent
                                )
                            } else {
                                settingsController.checkUpdates()
                            }
                        }
                        background: Rectangle {
                            color: Theme.accent
                            radius: Theme.radiusMedium
                        }
                        contentItem: Text {
                            text: parent.text
                            color: Theme.textOnColoredBtn
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
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
