import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Item {
    id: root
    property bool configChanged: false
    property int _pathVersion: 0

    Connections {
        target: settingsController
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
                spacing: 15

                Text {
                    text: "Remote path:"
                    color: Theme.accentText
                    font.bold: true
                    font.pixelSize: Theme.fontLabelSize
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
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
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        text: {
                            void(root._pathVersion)  // trigger re-evaluation
                            if (!settingsController) return ""
                            var base = settingsController.serverBaseFolder || ""
                            var tFolder = settingsController.serverTimeFolder || ""
                            var prefix = settingsController.ftpPrefix || ""
                            var suffix = settingsController.serverFileSuffix || ""

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
                spacing: 25

                // ── COLUMN 1: General ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "General"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Active:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    Switch {
                        checked: settingsController ? settingsController.serverActive : false
                        onToggled: { settingsController.serverActive = checked; root.configChanged = true }
                    }

                    Text { text: "Device type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: false }
                    ComboBox {
                        visible: false
                        Layout.fillWidth: true; model: ["Standard"]
                        currentIndex: 0
                        onActivated: { settingsController.serverDeviceType = currentText; root.configChanged = true }
                    }

                    Text { text: "Server name:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.serverName : ""
                        onTextEdited: { settingsController.serverName = text; root.configChanged = true }
                    }

                    Text { text: "Send interval (min):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["1", "2", "3", "5", "10", "15", "20", "30", "60"]
                        currentIndex: {
                            var v = settingsController ? String(settingsController.serverSendInterval) : "5"
                            var idx = model.indexOf(v)
                            return idx >= 0 ? idx : 3
                        }
                        onActivated: { settingsController.serverSendInterval = parseInt(currentText); root.configChanged = true }
                    }

                    Text { text: "Start time:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "00:00"
                        text: settingsController ? settingsController.serverStartTime : "00:00"
                        onTextEdited: { settingsController.serverStartTime = text; root.configChanged = true }
                    }
                }

                // ── COLUMN 2: FTP Connection ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "FTP Connection"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Host:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.ftpAddress : ""
                        onTextEdited: { settingsController.ftpAddress = text; root.configChanged = true }
                    }

                    Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? String(settingsController.ftpPort) : "22"
                        inputMethodHints: Qt.ImhDigitsOnly
                        onTextEdited: {
                            var p = parseInt(text)
                            if (!isNaN(p)) { settingsController.ftpPort = p; root.configChanged = true }
                        }
                    }

                    Text { text: "Username:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.ftpUsername : ""
                        onTextEdited: { settingsController.ftpUsername = text; root.configChanged = true }
                    }

                    Text { text: "Password:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        text: settingsController ? settingsController.ftpPassword : ""
                        onTextEdited: { settingsController.ftpPassword = text; root.configChanged = true }
                    }

                }

                // ── COLUMN 3: File & Folder Naming ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "File & Folder Naming"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Base folder:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.serverBaseFolder : ""
                        onTextEdited: { settingsController.serverBaseFolder = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "Time folder:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyyMMdd"]
                        currentIndex: {
                            var v = settingsController ? settingsController.serverTimeFolder : "yyyy/MM/dd"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { settingsController.serverTimeFolder = currentText; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "File prefix:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: settingsController ? settingsController.ftpPrefix : ""
                        onTextEdited: { settingsController.ftpPrefix = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: "File suffix:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyyMMddHHmmss", "yyyyMMddHHmm", "yyyyMMdd_HHmmss", "HHmmss"]
                        currentIndex: {
                            var v = settingsController ? settingsController.serverFileSuffix : "yyyyMMddHHmmss"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { settingsController.serverFileSuffix = currentText; root.configChanged = true; root._pathVersion++ }
                    }
                }
            }
        }
    }
}
