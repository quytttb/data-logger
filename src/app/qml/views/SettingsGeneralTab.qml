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
