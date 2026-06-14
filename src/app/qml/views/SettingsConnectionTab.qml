import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
            Layout.bottomMargin: 10
            
            background: Rectangle { 
                color: "transparent"
            }

            TabButton {
                text: "Local Sensors"
                width: implicitWidth + 30
            }
            TabButton {
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
                    spacing: 15

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: lsRow.implicitHeight + 40
                        color: Theme.bgPanel; radius: Theme.radiusCard
                        border.color: Theme.borderDefault; border.width: 1

                        RowLayout {
                            id: lsRow
                            anchors.fill: parent; anchors.margins: 20
                            spacing: 25

                            // ── Modbus RTU (Serial + Framing) ─────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                                Text {
                                    text: "Modbus RTU"
                                    color: Theme.accentText; font.bold: true; font.pixelSize: 15
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 25

                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
                                        Text { text: "Serial"; color: Theme.accentText; font.bold: true; font.pixelSize: 13 }

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
                                            ToolButton {
                                                icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/refresh.svg"
                                                icon.color: Theme.accentText; icon.width: 18; icon.height: 18
                                                onClicked: TesterController.refresh_ports()
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
                                        Text { text: "Data framing"; color: Theme.accentText; font.bold: true; font.pixelSize: 13 }

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
                    spacing: 15

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: nsRow.implicitHeight + 40
                        color: Theme.bgPanel; radius: Theme.radiusCard
                        border.color: Theme.borderDefault; border.width: 1

                        RowLayout {
                            id: nsRow
                            anchors.fill: parent; anchors.margins: 20
                            spacing: 25

                            // ── Modbus TCP Server ──────────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text {
                                        text: "Modbus TCP Server"
                                        color: Theme.accentText; font.bold: true; font.pixelSize: 15
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        implicitWidth: 10; implicitHeight: 10; radius: 5
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
                                    Layout.fillWidth: true; spacing: 10
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
                                        color: Theme.accentText; font.bold: true; font.pixelSize: 15
                                        Layout.fillWidth: true
                                    }
                                    Rectangle {
                                        implicitWidth: 10; implicitHeight: 10; radius: 5
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
                                    Layout.fillWidth: true; spacing: 10
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
                                    Layout.fillWidth: true; spacing: 6
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
                                    ToolButton {
                                        id: tokenShow
                                        checkable: true
                                        text: checked ? "Hide" : "Show"
                                        font.pixelSize: Theme.fontLabelSize - 1
                                    }
                                    ToolButton {
                                        text: "Regenerate"
                                        font.pixelSize: Theme.fontLabelSize - 1
                                        onClicked: SettingsController.regenerate_rest_token()
                                    }
                                    ToolButton {
                                        enabled: SettingsController.provisionQrAvailable
                                        icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/qr.svg"
                                        icon.color: Theme.accentText
                                        icon.width: 18
                                        icon.height: 18
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
