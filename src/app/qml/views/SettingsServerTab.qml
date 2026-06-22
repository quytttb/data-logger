import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

Item {
    id: root
    property bool configChanged: false
    property int _pathVersion: 0

    Connections {
        target: SettingsController
        function onConfigLoaded() { root._pathVersion++ }
        function onConfigSaved() { root._pathVersion++ }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formContent.implicitHeight + remotePath.height + 60
        clip: true; boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            width: flick.width; height: flick.contentHeight
            color: Theme.bgPanel; radius: Theme.radiusCard
            border.color: Theme.borderDefault; border.width: 1

            RowLayout {
                id: remotePath
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                height: 40
                spacing: Theme.spacingM

                Text {
                    text: "Remote path:"
                    color: Theme.accentText
                    font.bold: true
                    font.pixelSize: Theme.fontLabelSize
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.bgSeparator
                    radius: Theme.radiusTiny
                    border.color: Theme.accent
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.accent
                        font.pixelSize: AppTypography.bodySmall.pixelSize
                        font.bold: true
                        elide: Text.ElideRight
                        text: {
                            void(root._pathVersion)  // trigger re-evaluation
                            if (!SettingsController) return ""
                            var base = SettingsController.serverBaseFolder || ""
                            var tFolder = SettingsController.serverTimeFolder || ""
                            var prefix = SettingsController.ftpPrefix || ""
                            var suffix = SettingsController.serverFileSuffix || ""

                            var dir = ""
                            if (base) {
                                dir = base.startsWith("/") ? base : "/" + base
                            }
                            if (tFolder) {
                                if (dir && !dir.endsWith("/")) dir += "/"
                                dir += tFolder
                            }
                            if (dir && !dir.endsWith("/")) dir += "/"

                            return dir + prefix + suffix + ".txt"
                        }
                    }
                }
            }

            Rectangle {
                id: divider
                anchors.top: remotePath.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                height: 1
                color: Theme.borderDefault
            }

            RowLayout {
                id: formContent
                anchors.top: divider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                anchors.topMargin: 10
                spacing: Theme.spacingL

                // ── COLUMN 1: General ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "General"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spacingS
                        Text {
                            text: "Active"
                            color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Switch {
                            checked: SettingsController ? SettingsController.serverActive : false
                            onToggled: { SettingsController.serverActive = checked; root.configChanged = true }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text { text: "Device type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: false }
                    ComboBox {
                        visible: false
                        Layout.fillWidth: true; model: ["Standard"]
                        currentIndex: 0
                        onActivated: { SettingsController.serverDeviceType = currentText; root.configChanged = true }
                    }

                    Text { text: "Server name:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.serverName : ""
                        onTextEdited: { SettingsController.serverName = text; root.configChanged = true }
                    }

                    Text { text: "Send interval (min):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["1", "2", "3", "5", "10", "15", "20", "30", "60"]
                        currentIndex: {
                            var v = SettingsController ? String(SettingsController.serverSendInterval) : "5"
                            var idx = model.indexOf(v)
                            return idx >= 0 ? idx : 3
                        }
                        onActivated: { SettingsController.serverSendInterval = parseInt(currentText); root.configChanged = true }
                    }

                    Text { text: "Start time:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "00:00"
                        text: SettingsController ? SettingsController.serverStartTime : "00:00"
                        onTextEdited: { SettingsController.serverStartTime = text; root.configChanged = true }
                    }
                }

                // ── COLUMN 2: FTP Connection ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "FTP Connection"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    Text { text: "Host:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.ftpAddress : ""
                        onTextEdited: { SettingsController.ftpAddress = text; root.configChanged = true }
                    }

                    Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? String(SettingsController.ftpPort) : "21"
                        inputMethodHints: Qt.ImhDigitsOnly
                        onTextEdited: {
                            var p = parseInt(text)
                            if (!isNaN(p)) { SettingsController.ftpPort = p; root.configChanged = true }
                        }
                    }

                    Text { text: "Username:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.ftpUsername : ""
                        onTextEdited: { SettingsController.ftpUsername = text; root.configChanged = true }
                    }

                    Text { text: "Password:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        text: SettingsController ? SettingsController.ftpPassword : ""
                        onTextEdited: { SettingsController.ftpPassword = text; root.configChanged = true }
                    }

                }

                // ── COLUMN 3: File & Folder Naming ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "File & Folder Naming"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                    Text { text: "Base folder:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.serverBaseFolder : ""
                        onTextEdited: { SettingsController.serverBaseFolder = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "Time folder:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyyMMdd"]
                        currentIndex: {
                            var v = SettingsController ? SettingsController.serverTimeFolder : "yyyy/MM/dd"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { SettingsController.serverTimeFolder = currentText; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "File prefix:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? SettingsController.ftpPrefix : ""
                        onTextEdited: { SettingsController.ftpPrefix = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "File suffix:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyyMMddHHmmss", "yyyyMMddHHmm", "yyyyMMdd_HHmmss", "HHmmss"]
                        currentIndex: {
                            var v = SettingsController ? SettingsController.serverFileSuffix : "yyyyMMddHHmmss"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { SettingsController.serverFileSuffix = currentText; root.configChanged = true; root._pathVersion++ }
                    }
                }
            }
        }
    }
}
