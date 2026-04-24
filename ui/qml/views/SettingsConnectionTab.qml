import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"

Item {
    id: root
    property bool configChanged: false

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
                spacing: 25

                // ── COLUMN 1: Serial Port ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Serial Port"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

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
                            icon.source: "../../../assets/icons/refresh.svg"
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
                                var val = parseInt(editText)
                                if (!isNaN(val) && val > 0) { settingsController.serialBaudrate = val; root.configChanged = true }
                            }
                        }
                        onActivated: function(index) {
                            var val = parseInt(currentText)
                            if (!isNaN(val)) { settingsController.serialBaudrate = val; root.configChanged = true }
                        }
                    }
                }

                // ── COLUMN 2: Data Framing ──
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8

                    Text { text: "Data Framing"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Text { text: "Data bits:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        Layout.fillWidth: true; model: ["5", "6", "7", "8"]
                        Component.onCompleted: { currentIndex = model.indexOf(String(settingsController.serialBytesize)) }
                        onActivated: { settingsController.serialBytesize = parseInt(currentText); root.configChanged = true }
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
                        onActivated: { settingsController.serialStopbits = parseInt(currentText); root.configChanged = true }
                    }
                }

                // ── COLUMN 3: (reserved for future) ──
                Item { Layout.fillWidth: true }
            }
        }
    }
}
