import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Theme
import DataLogger.Core

Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    property bool isTesterMode: false

    readonly property string sensorType: {
        var r = dRegType.currentText
        if (r === "Discrete Inputs") return "DI"
        if (r === "Coils") return "DO"
        return "ANALOG"
    }

    readonly property bool isAnalog: sensorType === "ANALOG"
    readonly property bool isDI: sensorType === "DI"
    readonly property bool isDO: sensorType === "DO"
    readonly property bool isDigital: isDI || isDO

    property alias dActive: dActive
    property alias dName: dName
    property alias dSensorSymbol: dSensorSymbol
    property alias dUnit: dUnit
    property alias dPollInterval: dPollInterval
    property alias dReportIdx: dReportIdx
    property alias dSlave: dSlave
    property alias dAddr: dAddr
    property alias dRegType: dRegType
    property alias dDataType: dDataType
    property alias dDataFmt: dDataFmt

    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: Theme.spacingL

        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: "Basic Info"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Active:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true }
                Switch { id: dActive; checked: true }
            }

            Text { text: "Ký hiệu cảm biến:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: root.isAnalog }
            ComboBox {
                id: dSensorSymbol
                Layout.fillWidth: true
                visible: root.isAnalog
                editable: true
                model: SensorSymbols.symbols
            }

            Text { text: "Name:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            TextField { id: dName; Layout.fillWidth: true; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }

            Text { text: "Unit:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: root.isAnalog }
            ComboBox {
                id: dUnit; Layout.fillWidth: true; visible: root.isAnalog
                editable: true
                model: [
                    "°C", "°F", "%", "%RH",
                    "pH", "mg/L", "µg/L", "NTU",
                    "m³/h", "m³/s", "L/min", "L/h",
                    "m³", "m²", "m", "mm",
                    "mV", "V", "mA", "A",
                    "kPa", "Pa", "bar", "psi",
                    "dB", "dBA", "lux",
                    "ppm", "ppb", "mg/m³"
                ]
            }

            Text { text: "Poll interval (s):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode && root.isAnalog }
            SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true; visible: !root.isTesterMode && root.isAnalog }

            Text { text: "Report column index:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode && root.isAnalog }
            SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true; visible: !root.isTesterMode && root.isAnalog }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: "Modbus Settings"; color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

            RowLayout {
                spacing: Theme.spacingS; Layout.fillWidth: true
                Text { text: "Slave ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true }
            }

            RowLayout {
                spacing: Theme.spacingS; Layout.fillWidth: true
                Text { text: "Address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }
            }

            Text { text: "Register type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            ComboBox {
                id: dRegType; Layout.fillWidth: true
                model: ["Invalid", "Discrete Inputs", "Coils", "Input Registers", "Holding Registers"]
            }

            Text { text: "Data type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: root.isAnalog }
            ComboBox { id: dDataType; model: ["int16", "uint16", "int32", "uint32", "float32"]; Layout.fillWidth: true; visible: root.isAnalog }

            Text { text: "Endian format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: root.isAnalog }
            ComboBox { id: dDataFmt; model: ["AB", "BA", "ABCD", "CDAB", "BADC", "DCBA"]; Layout.fillWidth: true; visible: root.isAnalog }
        }
    }
}
