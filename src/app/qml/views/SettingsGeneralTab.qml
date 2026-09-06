pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    property bool configChanged: false
    readonly property var timezoneOptions: {
        var options = [
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
        var systemTz = AppDefaults.timezone
        var known = false
        for (var i = 0; i < options.length; ++i) {
            if (options[i].value === systemTz) {
                known = true
                break
            }
        }
        if (!known)
            options.unshift({ label: qsTr("System (%1)").arg(systemTz), value: systemTz })
        return options
    }

    MessagePopup { id: rebootConfirm }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formContent.implicitHeight + 40
        clip: true; boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            width: flick.width; height: flick.contentHeight
            color: AppColors.surfaceContainerLow; radius: AppTheme.cardRadius
            border.color: AppColors.outlineVariant; border.width: 1

            RowLayout {
                id: formContent
                anchors.fill: parent; anchors.margins: 20
                spacing: AppTheme.spacingL

                // ── COLUMN 1: Device ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: qsTr("Device Information"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    Text { text: qsTr("Device ID:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    Label {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.deviceId : ""
                        color: AppColors.onSurfaceVariant
                        font.pixelSize: AppTypography.bodyMedium.pixelSize
                        elide: Text.ElideRight
                    }

                    Text { text: qsTr("Station code:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.stationCode : ""
                        onTextEdited: { SettingsController.stationCode = text; root.configChanged = true }
                    }

                    Text { text: qsTr("Name Device:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.stationName : ""
                        onTextEdited: { SettingsController.stationName = text; root.configChanged = true }
                    }

                    Text { text: qsTr("Poll interval (s):"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
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

                    Text { text: qsTr("Date & Time"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    Text { text: qsTr("Time format:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["HH:mm:ss", "hh:mm:ss AP"]
                        currentIndex: {
                            var fmt = SettingsController ? SettingsController.timeFormat : AppDefaults.timeFormat
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { SettingsController.timeFormat = currentText; root.configChanged = true }
                    }

                    Text { text: qsTr("Date format:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["dd/MM/yyyy", "yyyy-MM-dd", "MM/dd/yyyy"]
                        currentIndex: {
                            var fmt = SettingsController ? SettingsController.dateFormat : AppDefaults.dateFormat
                            return Math.max(0, model.indexOf(fmt))
                        }
                        onActivated: { SettingsController.dateFormat = currentText; root.configChanged = true }
                    }

                    Text { text: qsTr("Timezone:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        // Fixed UTC offsets mapped to IANA zone ids that timedatectl
                        // accepts directly. Etc/GMT signs are inverted (UTC+7 == Etc/GMT-7)
                        // and carry no DST — ideal for stable logger timestamps.
                        model: root.timezoneOptions
                        currentIndex: {
                            var tz = SettingsController ? SettingsController.timezone : AppDefaults.timezone
                            // QTimeZone may report UTC as UTC/Etc/UTC/GMT;
                            // the fixed-offset list uses Etc/GMT for UTC+0.
                            if (tz === "UTC" || tz === "Etc/UTC" || tz === "GMT")
                                tz = "Etc/GMT"
                            return Math.max(0, indexOfValue(tz))
                        }
                        onActivated: { SettingsController.timezone = currentValue; root.configChanged = true }
                    }
                }

                // ── COLUMN 3: System ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: qsTr("System"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    Text { text: qsTr("Restart this device:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    AppButton {
                        Layout.fillWidth: true
                        text: qsTr("System Reboot")
                        iconName: "restart_alt"
                        kind: AppButton.Primary
                        fillColor: AppColors.error
                        onClicked: rebootConfirm.showConfirm(
                            "Confirm reboot",
                            "Reboot this device now? The application will start again automatically after boot.",
                            function() { if (SettingsController) SettingsController.rebootSystem() },
                            "Reboot",
                            AppColors.error)
                    }
                }
            }
        }
    }
}
