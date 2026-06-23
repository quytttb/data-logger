import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Network
import DataLogger.Components

Item {
    id: root
    property bool configChanged: false

    ProvisionQrPopup { id: provisionQrPopup }

    Connections {
        target: SettingsController
        function onConfigLoaded() {
            if (provisionQrPopup.visible)
                provisionQrPopup.refresh()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: connectionTabBar
            Layout.alignment: Qt.AlignLeft
            Layout.bottomMargin: Theme.spacingS
            
            background: Rectangle { 
                color: "transparent"
            }

            ThemedTabButton {
                text: "Local Sensors"
                width: implicitWidth + 30
            }
            ThemedTabButton {
                text: "Network Services"
                width: implicitWidth + 30
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: connectionTabBar.currentIndex

            // ── Local Sensors Tab ──────────────────────────────────────────
            Flickable {
                contentWidth: width
                contentHeight: lsFormContent.implicitHeight + 40
                clip: true; boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: lsFormContent
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: lsRow.implicitHeight + 40
                        color: Theme.bgPanel; radius: Theme.radiusCard
                        border.color: Theme.borderDefault; border.width: 1

                        RowLayout {
                            id: lsRow
                            anchors.fill: parent; anchors.margins: 20
                            spacing: Theme.spacingL

                            // ── Modbus RTU (Serial + Framing) ─────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                                Text {
                                    text: "Modbus RTU"
                                    color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacingL

                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
                                        Text { text: "Serial"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.bodySmall.pixelSize }

                                        Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 4
                                            ComboBox {
                                                id: masterPortCombo
                                                Layout.fillWidth: true
                                                model: TesterController.availablePorts
                                                editable: true
                                                property bool ready: false
                                                Component.onCompleted: { editText = SettingsController.serialPort; ready = true }
                                                Connections {
                                                    target: SettingsController
                                                    function onConfigLoaded() {
                                                        masterPortCombo.ready = false
                                                        masterPortCombo.editText = SettingsController.serialPort
                                                        masterPortCombo.ready = true
                                                    }
                                                }
                                                onEditTextChanged: { if (ready) { SettingsController.serialPort = editText; root.configChanged = true } }
                                                onActivated: function(index) { SettingsController.serialPort = currentText; root.configChanged = true }
                                            }
                                            Button {
                                                id: refreshPortsBtn
                                                implicitWidth: 32
                                                implicitHeight: 32
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
                                                onClicked: TesterController.refresh_ports()
                                                
                                                contentItem: Item {
                                                    anchors.fill: parent
                                                    UiIcon {
                                                        anchors.centerIn: parent
                                                        name: "refresh"
                                                        size: AppTheme.iconSizeSm
                                                        iconColor: AppColors.buttonIconOnFilled
                                                    }
                                                }
                                                background: Rectangle {
                                                    anchors.fill: parent
                                                    color: !refreshPortsBtn.enabled ? Theme.btnBgDisabled : Theme.accent
                                                    radius: Theme.radiusMedium
                                                    opacity: refreshPortsBtn.pressed ? 0.75 : 1.0
                                                }
                                            }
                                        }

                                        Text { text: "Baudrate:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            id: masterBaudCombo
                                            Layout.fillWidth: true
                                            model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                                            editable: true
                                            property bool ready: false
                                            Component.onCompleted: { editText = String(SettingsController.serialBaudrate); ready = true }
                                            Connections {
                                                target: SettingsController
                                                function onConfigLoaded() {
                                                    masterBaudCombo.ready = false
                                                    masterBaudCombo.editText = String(SettingsController.serialBaudrate)
                                                    masterBaudCombo.ready = true
                                                }
                                            }
                                            onEditTextChanged: {
                                                if (ready) {
                                                    var val = parseInt(editText, 10)
                                                    if (!isNaN(val) && val > 0) { SettingsController.serialBaudrate = val; root.configChanged = true }
                                                }
                                            }
                                            onActivated: function(index) {
                                                var val = parseInt(currentText, 10)
                                                if (!isNaN(val)) { SettingsController.serialBaudrate = val; root.configChanged = true }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
                                        Text { text: "Data framing"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.bodySmall.pixelSize }

                                        Text { text: "Data bits:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["5", "6", "7", "8"]
                                            Component.onCompleted: { currentIndex = model.indexOf(String(SettingsController.serialBytesize)) }
                                            onActivated: { SettingsController.serialBytesize = parseInt(currentText, 10); root.configChanged = true }
                                        }

                                        Text { text: "Parity:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["N", "E", "O"]
                                            Component.onCompleted: { currentIndex = model.indexOf(SettingsController.serialParity) }
                                            onActivated: { SettingsController.serialParity = currentText; root.configChanged = true }
                                        }

                                        Text { text: "Stop bits:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["1", "2"]
                                            Component.onCompleted: { currentIndex = model.indexOf(String(SettingsController.serialStopbits)) }
                                            onActivated: { SettingsController.serialStopbits = parseInt(currentText, 10); root.configChanged = true }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Network Services Tab ───────────────────────────────────────
            Flickable {
                contentWidth: width
                contentHeight: nsFormContent.implicitHeight + 40
                clip: true; boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: nsFormContent
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: nsRow.implicitHeight + 40
                        color: Theme.bgPanel; radius: Theme.radiusCard
                        border.color: Theme.borderDefault; border.width: 1

                        RowLayout {
                            id: nsRow
                            anchors.fill: parent; anchors.margins: 20
                            spacing: Theme.spacingL

                            // ── Modbus TCP Server ──────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text {
                                        text: "Modbus TCP Server"
                                        color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        implicitWidth: 10; implicitHeight: 10; radius: width / 2
                                        color: ModbusTcpServerService.state === "listening" ? AppColors.success
                                             : ModbusTcpServerService.state === "error" ? AppColors.error
                                             : ModbusTcpServerService.state === "starting" ? AppColors.warning
                                             : AppColors.onSurfaceVariant
                                    }
                                    Text {
                                        text: ModbusTcpServerService.state === "listening" ? "Listening"
                                            : ModbusTcpServerService.state === "error" ? "Error"
                                            : ModbusTcpServerService.state === "starting" ? "Starting…"
                                            : "Stopped"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacingS
                                    Text {
                                        text: "Active"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Switch {
                                        id: tcpActiveSwitch
                                        checked: SettingsController.modbusTcpEnabled
                                        Connections {
                                            target: SettingsController
                                            function onConfigLoaded() {
                                                tcpActiveSwitch.checked = SettingsController.modbusTcpEnabled
                                            }
                                        }
                                        onToggled: { SettingsController.modbusTcpEnabled = checked; root.configChanged = true }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Text { text: "Bind address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: tcpBindField
                                    Layout.fillWidth: true
                                    EnterKeyAction.label: qsTr("OK")
                                    text: SettingsController.modbusTcpBind
                                    placeholderText: "0.0.0.0"
                                    selectByMouse: true
                                    Connections {
                                        target: SettingsController
                                        function onConfigLoaded() {
                                            tcpBindField.text = SettingsController.modbusTcpBind
                                        }
                                    }
                                    onTextEdited: { SettingsController.modbusTcpBind = text; root.configChanged = true }
                                }

                                Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: tcpPortField
                                    Layout.fillWidth: true
                                    text: SettingsController ? String(SettingsController.modbusTcpPort) : "5020"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    EnterKeyAction.label: qsTr("OK")
                                    selectByMouse: true
                                    Connections {
                                        target: SettingsController
                                        function onConfigLoaded() {
                                            tcpPortField.text = String(SettingsController.modbusTcpPort)
                                        }
                                    }
                                    onTextEdited: {
                                        var p = parseInt(text, 10)
                                        if (!isNaN(p) && p >= 1 && p <= 65535) {
                                            SettingsController.modbusTcpPort = p
                                            root.configChanged = true
                                        }
                                    }
                                }

                                Text { text: "Unit ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                SpinBox {
                                    id: tcpUnitSpin
                                    Layout.fillWidth: true
                                    from: 1; to: 247; stepSize: 1; editable: true
                                    validator: IntValidator { bottom: 1; top: 247 }
                                    textFromValue: function(value) { return String(Math.round(value)) }
                                    valueFromText: function(text) {
                                        var n = parseInt(text, 10)
                                        if (isNaN(n)) return tcpUnitSpin.from
                                        return Math.min(tcpUnitSpin.to, Math.max(tcpUnitSpin.from, n))
                                    }
                                    value: SettingsController.modbusTcpUnitId
                                    Connections {
                                        target: SettingsController
                                        function onConfigLoaded() {
                                            tcpUnitSpin.value = SettingsController.modbusTcpUnitId
                                        }
                                    }
                                    onValueModified: {
                                        SettingsController.modbusTcpUnitId = Math.round(value)
                                        root.configChanged = true
                                    }
                                }

                                Text {
                                    text: ModbusTcpServerService.lastError.length > 0
                                          ? ("⚠ " + ModbusTcpServerService.lastError)
                                          : ""
                                    visible: ModbusTcpServerService.lastError.length > 0
                                    color: AppColors.error; font.pixelSize: Theme.fontLabelSize - 1
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                            }

                            // ── HTTP REST Server (Remote Config cho Central App) ─────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text {
                                        text: "HTTP REST Server"
                                        color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        implicitWidth: 10; implicitHeight: 10; radius: width / 2
                                        color: RestApiService.state === "listening" ? AppColors.success
                                             : RestApiService.state === "error" ? AppColors.error
                                             : RestApiService.state === "starting" ? AppColors.warning
                                             : AppColors.onSurfaceVariant
                                    }
                                    Text {
                                        text: RestApiService.state === "listening" ? "Listening"
                                            : RestApiService.state === "error" ? "Error"
                                            : RestApiService.state === "starting" ? "Starting…"
                                            : "Stopped"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacingS
                                    Text {
                                        text: "Active"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Switch {
                                        id: restActiveSwitch
                                        checked: SettingsController.restApiEnabled
                                        Connections {
                                            target: SettingsController
                                            function onConfigLoaded() {
                                                restActiveSwitch.checked = SettingsController.restApiEnabled
                                            }
                                        }
                                        onToggled: { SettingsController.restApiEnabled = checked; root.configChanged = true }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Text { text: "Bind address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: restBindField
                                    Layout.fillWidth: true
                                    EnterKeyAction.label: qsTr("OK")
                                    text: SettingsController.restApiBind
                                    placeholderText: "0.0.0.0"
                                    selectByMouse: true
                                    Connections {
                                        target: SettingsController
                                        function onConfigLoaded() {
                                            restBindField.text = SettingsController.restApiBind
                                        }
                                    }
                                    onTextEdited: { SettingsController.restApiBind = text; root.configChanged = true }
                                }

                                Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: restPortField
                                    Layout.fillWidth: true
                                    text: SettingsController ? String(SettingsController.restApiPort) : "8080"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    EnterKeyAction.label: qsTr("OK")
                                    selectByMouse: true
                                    Connections {
                                        target: SettingsController
                                        function onConfigLoaded() {
                                            restPortField.text = String(SettingsController.restApiPort)
                                        }
                                    }
                                    onTextEdited: {
                                        var p = parseInt(text, 10)
                                        if (!isNaN(p) && p >= 1 && p <= 65535) {
                                            SettingsController.restApiPort = p
                                            root.configChanged = true
                                        }
                                    }
                                }

                                Text { text: "API token:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacingS
                                    TextField {
                                        id: restTokenField
                                        Layout.fillWidth: true
                                        readOnly: true
                                        selectByMouse: true
                                        echoMode: tokenShow.checked ? TextInput.Normal : TextInput.Password
                                        text: SettingsController.restApiToken
                                        Connections {
                                            target: SettingsController
                                            function onConfigLoaded() {
                                                restTokenField.text = SettingsController.restApiToken
                                            }
                                        }
                                    }
                                    AppButton {
                                        id: tokenShow
                                        checkable: true
                                        text: checked ? "Hide" : "Show"
                                        variant: "outlined"
                                        font.pixelSize: Theme.fontLabelSize - 1
                                    }
                                    AppButton {
                                        text: "Regenerate"
                                        variant: "outlined"
                                        font.pixelSize: Theme.fontLabelSize - 1
                                        onClicked: SettingsController.regenerateRestToken()
                                    }
                                    AppButton {
                                        enabled: SettingsController.provisionQrAvailable
                                        iconName: "qrCode"
                                        variant: "outlined"
                                        onClicked: {
                                            provisionQrPopup.refresh()
                                            provisionQrPopup.open()
                                        }
                                    }
                                }

                                Text {
                                    text: RestApiService.lastError.length > 0
                                          ? ("⚠ " + RestApiService.lastError)
                                          : ""
                                    visible: RestApiService.lastError.length > 0
                                    color: AppColors.error; font.pixelSize: Theme.fontLabelSize - 1
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
