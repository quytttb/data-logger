pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme

Item {
    id: root
    property bool configChanged: false
    property int _pathVersion: 0
    property alias transmissionTab: transmissionTab

    Connections {
        target: SettingsController
        function onConfigLoaded() { root._pathVersion++ }
        function onConfigSaved() { root._pathVersion++ }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: serverTabBar
            Layout.alignment: Qt.AlignLeft
            Layout.bottomMargin: AppTheme.spacingS
            background: Rectangle { color: "transparent" }

            ThemedTabButton { text: qsTr("Cài đặt chung"); width: implicitWidth + 30 }
            ThemedTabButton { text: qsTr("Thông số truyền"); width: implicitWidth + 30 }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: serverTabBar.currentIndex

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formContent.implicitHeight + remotePath.height + 60
        clip: true; boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            width: flick.width; height: flick.contentHeight
            color: AppColors.surfaceContainerLow; radius: AppTheme.cardRadius
            border.color: AppColors.outlineVariant; border.width: 1

            RowLayout {
                id: remotePath
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                height: 40
                spacing: AppTheme.spacingM

                Text {
                    text: qsTr("Remote path:")
                    color: AppColors.accentColor
                    font.bold: true
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: AppColors.surfaceContainerHigh
                    radius: AppTheme.radiusTiny
                    border.color: AppColors.primaryColor
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: AppColors.primaryColor
                        font.pixelSize: AppTypography.bodySmall.pixelSize
                        font.bold: true
                        elide: Text.ElideRight
                        text: {
                            void(root._pathVersion)  // trigger re-evaluation
                            if (!SettingsController) return ""
                            var base = SettingsController.serverBaseFolder || ""
                            var tFolder = SettingsController.serverTimeFolder || ""
                            var prefix = SettingsController.filePrefix || ""
                            var suffixPat = SettingsController.fileSuffix || "yyyyMMddHHmmss"
                            var suffix = Qt.formatDateTime(new Date(), suffixPat)

                            var dir = ""
                            if (base) {
                                dir = base.startsWith("/") ? base : "/" + base
                            }
                            if (tFolder) {
                                if (dir && !dir.endsWith("/")) dir += "/"
                                dir += Qt.formatDateTime(new Date(), tFolder)
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
                color: AppColors.outlineVariant
            }

            RowLayout {
                id: formContent
                anchors.top: divider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                anchors.topMargin: 10
                spacing: AppTheme.spacingL

                // ── COLUMN 1: General ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: qsTr("General"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    RowLayout {
                        Layout.fillWidth: true; spacing: AppTheme.spacingS
                        Text {
                            text: qsTr("Active")
                            color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Switch {
                            checked: SettingsController ? SettingsController.serverActive : false
                            onToggled: { SettingsController.serverActive = checked; root.configChanged = true }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text { text: qsTr("Device type:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: false }
                    ComboBox {
                        visible: false
                        Layout.fillWidth: true; model: ["Standard"]
                        currentIndex: 0
                        onActivated: { SettingsController.serverDeviceType = currentText; root.configChanged = true }
                    }

                    Text { text: qsTr("Server name:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.serverName : ""
                        onTextEdited: { SettingsController.serverName = text; root.configChanged = true }
                    }

                    Text { text: qsTr("Send interval (min):"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
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

                    Text { text: qsTr("Start time:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        placeholderText: qsTr("00:00")
                        text: SettingsController ? SettingsController.serverStartTime : "00:00"
                        onTextEdited: { SettingsController.serverStartTime = text; root.configChanged = true }
                    }
                }

                // ── COLUMN 2: FTP Connection ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: qsTr("FTP Connection"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    Text { text: qsTr("Host:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.ftpAddress : ""
                        onTextEdited: { SettingsController.ftpAddress = text; root.configChanged = true }
                    }

                    Text { text: qsTr("Port:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        text: SettingsController ? String(SettingsController.ftpPort) : "21"
                        inputMethodHints: Qt.ImhDigitsOnly
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        onTextEdited: {
                            var p = parseInt(text)
                            if (!isNaN(p)) { SettingsController.ftpPort = p; root.configChanged = true }
                        }
                    }

                    Text { text: qsTr("Username:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.ftpUsername : ""
                        onTextEdited: { SettingsController.ftpUsername = text; root.configChanged = true }
                    }

                    Text { text: qsTr("Password:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.ftpPassword : ""
                        onTextEdited: { SettingsController.ftpPassword = text; root.configChanged = true }
                    }

                }

                // ── COLUMN 3: File & Folder Naming ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: qsTr("File & Folder Naming"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                    Text { text: qsTr("Station folder:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.serverBaseFolder : ""
                        onTextEdited: { SettingsController.serverBaseFolder = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: qsTr("Date subfolder:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyyMMdd"]
                        currentIndex: {
                            var v = SettingsController ? SettingsController.serverTimeFolder : "yyyy/MM/dd"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { SettingsController.serverTimeFolder = currentText; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: qsTr("File prefix:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField {
                        Layout.fillWidth: true
                        EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK")
                        text: SettingsController ? SettingsController.filePrefix : ""
                        onTextEdited: { SettingsController.filePrefix = text; root.configChanged = true; root._pathVersion++ }
                    }

                    Text { text: qsTr("File suffix:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["yyyyMMddHHmmss", "yyyyMMddHHmm", "yyyyMMdd_HHmmss", "HHmmss"]
                        currentIndex: {
                            var v = SettingsController ? SettingsController.fileSuffix : "yyyyMMddHHmmss"
                            return Math.max(0, model.indexOf(v))
                        }
                        onActivated: { SettingsController.fileSuffix = currentText; root.configChanged = true; root._pathVersion++ }
                    }
                }
            }
        }
    }
            }

            SettingsTransmissionTab {
                id: transmissionTab
                Layout.fillWidth: true
                Layout.fillHeight: true
                onConfigChangedChanged: {
                    if (configChanged)
                        root.configChanged = true
                }
            }
        }
    }
}
