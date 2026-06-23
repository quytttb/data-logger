import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

Item {
    id: root
    property bool configChanged: false

    MessagePopup { id: rebootConfirm }

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
                spacing: Theme.spacingL

                // ── COLUMN 1: Device ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Device Information"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    Text { text: "Device ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.stationCode : ""
                        onTextEdited: { SettingsController.stationCode = text; root.configChanged = true }
                    }

                    Text { text: "Name Device:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.stationName : ""
                        onTextEdited: { SettingsController.stationName = text; root.configChanged = true }
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
                        value: SettingsController ? SettingsController.pollInterval : 3
                        Connections {
                            target: SettingsController
                            function onConfigLoaded() {
                                pollSpin.value = SettingsController.pollInterval
                            }
                        }
                        onValueModified: {
                            SettingsController.pollInterval = Math.round(value)
                            root.configChanged = true
                        }
                    }

                }

                // ── COLUMN 2: Date & Time ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Date & Time"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    Text { text: "Time format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["HH:mm:ss", "hh:mm:ss AP"]
                        currentIndex: {
                            var fmt = SettingsController ? SettingsController.timeFormat : "HH:mm:ss"
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { SettingsController.timeFormat = currentText; root.configChanged = true }
                    }

                    Text { text: "Date format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy"]
                        currentIndex: {
                            var fmt = SettingsController ? SettingsController.dateFormat : "dd/MM/yyyy"
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { SettingsController.dateFormat = currentText; root.configChanged = true }
                    }

                    Text { text: "Timezone:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        // Fixed UTC offsets mapped to IANA zone ids that timedatectl
                        // accepts directly. Etc/GMT signs are inverted (UTC+7 == Etc/GMT-7)
                        // and carry no DST — ideal for stable logger timestamps.
                        model: [
                            { label: "UTC-12", value: "Etc/GMT+12" },
                            { label: "UTC-11", value: "Etc/GMT+11" },
                            { label: "UTC-10", value: "Etc/GMT+10" },
                            { label: "UTC-9",  value: "Etc/GMT+9" },
                            { label: "UTC-8",  value: "Etc/GMT+8" },
                            { label: "UTC-7",  value: "Etc/GMT+7" },
                            { label: "UTC-6",  value: "Etc/GMT+6" },
                            { label: "UTC-5",  value: "Etc/GMT+5" },
                            { label: "UTC-4",  value: "Etc/GMT+4" },
                            { label: "UTC-3",  value: "Etc/GMT+3" },
                            { label: "UTC-2",  value: "Etc/GMT+2" },
                            { label: "UTC-1",  value: "Etc/GMT+1" },
                            { label: "UTC+0",  value: "Etc/GMT" },
                            { label: "UTC+1",  value: "Etc/GMT-1" },
                            { label: "UTC+2",  value: "Etc/GMT-2" },
                            { label: "UTC+3",  value: "Etc/GMT-3" },
                            { label: "UTC+4",  value: "Etc/GMT-4" },
                            { label: "UTC+5",  value: "Etc/GMT-5" },
                            { label: "UTC+5:30", value: "Asia/Kolkata" },
                            { label: "UTC+6",  value: "Etc/GMT-6" },
                            { label: "UTC+7",  value: "Etc/GMT-7" },
                            { label: "UTC+8",  value: "Etc/GMT-8" },
                            { label: "UTC+9",  value: "Etc/GMT-9" },
                            { label: "UTC+10", value: "Etc/GMT-10" },
                            { label: "UTC+11", value: "Etc/GMT-11" },
                            { label: "UTC+12", value: "Etc/GMT-12" }
                        ]
                        currentIndex: {
                            var tz = SettingsController ? SettingsController.timezone : "Etc/GMT-7"
                            return Math.max(0, indexOfValue(tz))
                        }
                        onActivated: { SettingsController.timezone = currentValue; root.configChanged = true }
                    }
                }

                // ── COLUMN 3: System ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "System"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    Text { text: "Restart this device:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    AppButton {
                        Layout.fillWidth: true
                        text: "System Reboot"
                        iconName: "restart_alt"
                        variant: "filled"
                        accent: Theme.btnStop
                        onClicked: rebootConfirm.showConfirm(
                            "Confirm reboot",
                            "Reboot this device now? The application will start again automatically after boot.",
                            function() { if (SettingsController) SettingsController.rebootSystem() },
                            "Reboot",
                            Theme.btnStop)
                    }
                }
            }
        }
    }
}
