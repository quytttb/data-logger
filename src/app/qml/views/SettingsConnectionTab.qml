import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Components

Item {
    id: root
    property bool configChanged: false

    ProvisionQrPopup { id: provisionQrPopup }

    Connections {
        target: settingsController
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
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

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
                                                model: testerController.availablePorts
                                                editable: true
                                                property bool ready: false
                                                Component.onCompleted: { editText = settingsController.serialPort; ready = true }
                                                Connections {
                                                    target: settingsController
                                                    function onConfigLoaded() {
                                                        masterPortCombo.ready = false
                                                        masterPortCombo.editText = settingsController.serialPort
                                                        masterPortCombo.ready = true
                                                    }
                                                }
                                                onEditTextChanged: { if (ready) { settingsController.serialPort = editText; root.configChanged = true } }
                                                onActivated: function(index) { settingsController.serialPort = currentText; root.configChanged = true }
                                            }
                                            ToolButton {
                                                icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/refresh.svg"
                                                icon.color: Theme.accentText; icon.width: 18; icon.height: 18
                                                onClicked: testerController.refresh_ports()
                                            }
                                        }

                                        Text { text: "Baudrate:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            id: masterBaudCombo
                                            Layout.fillWidth: true
                                            model: ["1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200"]
                                            editable: true
                                            property bool ready: false
                                            Component.onCompleted: { editText = String(settingsController.serialBaudrate); ready = true }
                                            Connections {
                                                target: settingsController
                                                function onConfigLoaded() {
                                                    masterBaudCombo.ready = false
                                                    masterBaudCombo.editText = String(settingsController.serialBaudrate)
                                                    masterBaudCombo.ready = true
                                                }
                                            }
                                            onEditTextChanged: {
                                                if (ready) {
                                                    var val = parseInt(editText, 10)
                                                    if (!isNaN(val) && val > 0) { settingsController.serialBaudrate = val; root.configChanged = true }
                                                }
                                            }
                                            onActivated: function(index) {
                                                var val = parseInt(currentText, 10)
                                                if (!isNaN(val)) { settingsController.serialBaudrate = val; root.configChanged = true }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
                                        Text { text: "Data framing"; color: Theme.accentText; font.bold: true; font.pixelSize: 13 }

                                        Text { text: "Data bits:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["5", "6", "7", "8"]
                                            Component.onCompleted: { currentIndex = model.indexOf(String(settingsController.serialBytesize)) }
                                            onActivated: { settingsController.serialBytesize = parseInt(currentText, 10); root.configChanged = true }
                                        }

                                        Text { text: "Parity:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["N", "E", "O"]
                                            Component.onCompleted: { currentIndex = model.indexOf(settingsController.serialParity) }
                                            onActivated: { settingsController.serialParity = currentText; root.configChanged = true }
                                        }

                                        Text { text: "Stop bits:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                        ComboBox {
                                            Layout.fillWidth: true; model: ["1", "2"]
                                            Component.onCompleted: { currentIndex = model.indexOf(String(settingsController.serialStopbits)) }
                                            onActivated: { settingsController.serialStopbits = parseInt(currentText, 10); root.configChanged = true }
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
                                        color: modbusTcpService.state === "listening" ? "#7dffa2"
                                             : modbusTcpService.state === "error" ? "#ff5353"
                                             : modbusTcpService.state === "starting" ? "#d4a62d"
                                             : "#888888"
                                    }
                                    Text {
                                        text: modbusTcpService.state === "listening" ? "Listening"
                                            : modbusTcpService.state === "error" ? "Error"
                                            : modbusTcpService.state === "starting" ? "Starting…"
                                            : "Stopped"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Text {
                                        text: "Active"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Switch {
                                        id: tcpActiveSwitch
                                        checked: settingsController.modbusTcpEnabled
                                        Connections {
                                            target: settingsController
                                            function onConfigLoaded() {
                                                tcpActiveSwitch.checked = settingsController.modbusTcpEnabled
                                            }
                                        }
                                        onToggled: { settingsController.modbusTcpEnabled = checked; root.configChanged = true }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Text { text: "Bind address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: tcpBindField
                                    Layout.fillWidth: true
                                    text: settingsController.modbusTcpBind
                                    placeholderText: "0.0.0.0"
                                    selectByMouse: true
                                    Connections {
                                        target: settingsController
                                        function onConfigLoaded() {
                                            tcpBindField.text = settingsController.modbusTcpBind
                                        }
                                    }
                                    onTextEdited: { settingsController.modbusTcpBind = text; root.configChanged = true }
                                }

                                Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: tcpPortField
                                    Layout.fillWidth: true
                                    text: settingsController ? String(settingsController.modbusTcpPort) : "5020"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    selectByMouse: true
                                    Connections {
                                        target: settingsController
                                        function onConfigLoaded() {
                                            tcpPortField.text = String(settingsController.modbusTcpPort)
                                        }
                                    }
                                    onTextEdited: {
                                        var p = parseInt(text, 10)
                                        if (!isNaN(p) && p >= 1 && p <= 65535) {
                                            settingsController.modbusTcpPort = p
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
                                    value: settingsController.modbusTcpUnitId
                                    Connections {
                                        target: settingsController
                                        function onConfigLoaded() {
                                            tcpUnitSpin.value = settingsController.modbusTcpUnitId
                                        }
                                    }
                                    onValueModified: {
                                        settingsController.modbusTcpUnitId = Math.round(value)
                                        root.configChanged = true
                                    }
                                }

                                Text {
                                    text: modbusTcpService.lastError.length > 0
                                          ? ("⚠ " + modbusTcpService.lastError)
                                          : ""
                                    visible: modbusTcpService.lastError.length > 0
                                    color: "#ff8080"; font.pixelSize: Theme.fontLabelSize - 1
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
                                        color: restApiService.state === "listening" ? "#7dffa2"
                                             : restApiService.state === "error" ? "#ff5353"
                                             : restApiService.state === "starting" ? "#d4a62d"
                                             : "#888888"
                                    }
                                    Text {
                                        text: restApiService.state === "listening" ? "Listening"
                                            : restApiService.state === "error" ? "Error"
                                            : restApiService.state === "starting" ? "Starting…"
                                            : "Stopped"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Text {
                                        text: "Active"
                                        color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Switch {
                                        id: restActiveSwitch
                                        checked: settingsController.restApiEnabled
                                        Connections {
                                            target: settingsController
                                            function onConfigLoaded() {
                                                restActiveSwitch.checked = settingsController.restApiEnabled
                                            }
                                        }
                                        onToggled: { settingsController.restApiEnabled = checked; root.configChanged = true }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Text { text: "Bind address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: restBindField
                                    Layout.fillWidth: true
                                    text: settingsController.restApiBind
                                    placeholderText: "0.0.0.0"
                                    selectByMouse: true
                                    Connections {
                                        target: settingsController
                                        function onConfigLoaded() {
                                            restBindField.text = settingsController.restApiBind
                                        }
                                    }
                                    onTextEdited: { settingsController.restApiBind = text; root.configChanged = true }
                                }

                                Text { text: "Port:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                                TextField {
                                    id: restPortField
                                    Layout.fillWidth: true
                                    text: settingsController ? String(settingsController.restApiPort) : "8080"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    selectByMouse: true
                                    Connections {
                                        target: settingsController
                                        function onConfigLoaded() {
                                            restPortField.text = String(settingsController.restApiPort)
                                        }
                                    }
                                    onTextEdited: {
                                        var p = parseInt(text, 10)
                                        if (!isNaN(p) && p >= 1 && p <= 65535) {
                                            settingsController.restApiPort = p
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
                                        text: settingsController.restApiToken
                                        Connections {
                                            target: settingsController
                                            function onConfigLoaded() {
                                                restTokenField.text = settingsController.restApiToken
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
                                        onClicked: settingsController.regenerate_rest_token()
                                    }
                                    ToolButton {
                                        enabled: settingsController.provisionQrAvailable
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
                                    text: restApiService.lastError.length > 0
                                          ? ("⚠ " + restApiService.lastError)
                                          : ""
                                    visible: restApiService.lastError.length > 0
                                    color: "#ff8080"; font.pixelSize: Theme.fontLabelSize - 1
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
