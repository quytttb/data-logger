pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    property bool configChanged: false

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formContent.implicitHeight + 40
        clip: true; boundsBehavior: Flickable.StopAtBounds

        ElevatedPane {
            width: flick.width
            height: flick.contentHeight
            padding: 20
            contentSpacing: 0

            RowLayout {
                id: formContent
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                    Text { text: qsTr("Monitor layout:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Grid", "List"]
                        currentIndex: {
                            var mode = SettingsController ? SettingsController.monitorViewMode : "grid"
                            return mode === "list" ? 1 : 0
                        }
                        onActivated: {
                            SettingsController.monitorViewMode = (currentIndex === 1 ? "list" : "grid")
                            root.configChanged = true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { 
                            text: qsTr("Show DI/DO sensors:") 
                            color: AppColors.onSurfaceVariant 
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.fillWidth: true
                        }
                        Switch {
                            checked: SettingsController ? SettingsController.monitorShowDigitalIO : true
                            onToggled: {
                                SettingsController.monitorShowDigitalIO = checked
                                root.configChanged = true
                            }
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
                        id: timezoneCombo
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        // Fixed UTC offsets mapped to IANA zone ids that timedatectl
                        // accepts directly. Etc/GMT signs are inverted (UTC+7 == Etc/GMT-7)
                        // and carry no DST — ideal for stable logger timestamps.
                        // Timezone table lives in C++ (TimezoneOptions, single
                        // source of truth shared with the DB migration).
                        model: AppDefaults.timezoneOptions
                        currentIndex: AppDefaults.timezoneIndex(
                            SettingsController ? SettingsController.timezone : AppDefaults.timezone)
                        Connections {
                            target: SettingsController
                            function onConfigLoaded() {
                                timezoneCombo.currentIndex = AppDefaults.timezoneIndex(
                                            SettingsController.timezone)
                            }
                        }
                        onActivated: { SettingsController.timezone = currentValue; root.configChanged = true }
                    }

                    Text { text: qsTr("Language:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        id: localeCombo
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        // App-level UI locale (vi/en). The edge runs as a
                        // Vietnam-only kiosk, so "vi" is the default; the value
                        // is applied at boot via QLocale::setDefault().
                        model: AppDefaults.localeOptions
                        currentIndex: AppDefaults.localeIndex(
                            SettingsController ? SettingsController.uiLocale : AppDefaults.uiLocale)
                        Connections {
                            target: SettingsController
                            function onConfigLoaded() {
                                localeCombo.currentIndex = AppDefaults.localeIndex(
                                            SettingsController.uiLocale)
                            }
                        }
                        onActivated: { SettingsController.uiLocale = currentValue; root.configChanged = true }
                    }
                }

            }
        }
    }
}
