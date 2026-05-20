import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// TAB 0: Basic Info & Modbus Settings
// When sensorType is "DI" or "DO", analog-specific fields are hidden.
Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    property bool isTesterMode: false
    readonly property string sensorType: {
        var r = dRegType.currentText;
        if (r === "Discrete Inputs") return "DI";
        if (r === "Coils") return "DO";
        return "ANALOG";
    }

    // Convenience flags
    readonly property bool isAnalog: sensorType === "ANALOG"
    readonly property bool isDI: sensorType === "DI"
    readonly property bool isDO: sensorType === "DO"
    readonly property bool isDigital: isDI || isDO

    // ── Expose form fields ──
    property alias dActive: dActive
    property alias dName: dName
    property alias dUnit: dUnit
    property alias dPollInterval: dPollInterval
    property alias dReportIdx: dReportIdx
    property alias dSlave: dSlave
    property alias dAddr: dAddr
    property alias dRegType: dRegType
    property alias dDataType: dDataType
    property alias dDataFmt: dDataFmt
    property alias dDiType: dDiType


    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: 25

        // ── COLUMN 1: Basic Info ──
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: "Basic Info"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Active:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true }
                Switch { id: dActive; checked: true }
            }

            Text { text: "Name:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            TextField { id: dName; Layout.fillWidth: true }

            // Unit — hidden for DI/DO
            Text { text: "Unit:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: isAnalog }
            ComboBox {
                id: dUnit; Layout.fillWidth: true; visible: isAnalog
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

            // DI-specific: Status code (di_type)
            Text { text: "Status Code (di_type):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: isDI }
            ComboBox {
                id: dDiType; Layout.fillWidth: true; visible: isDI
                editable: true
                model: ["00 — Monitoring", "01 — Calibrating", "02 — Error", "03 — Maintenance"]
                property string diTypeValue: {
                    var t = currentText.trim()
                    if (t.indexOf("—") >= 0) return t.split("—")[0].trim()
                    return t
                }
            }

            // Poll interval — hidden for DI/DO
            Text { text: "Poll interval (s):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode && isAnalog }
            SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true; visible: !root.isTesterMode && isAnalog }

            // Report column index — hidden for DI/DO
            Text { text: "Report column index:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode && isAnalog }
            SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true; visible: !root.isTesterMode && isAnalog }
        }

        // ── COLUMN 2: Modbus Settings ──
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: "Modbus Settings"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

            RowLayout {
                spacing: 10; Layout.fillWidth: true
                Text { text: "Slave ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true }
            }

            RowLayout {
                spacing: 10; Layout.fillWidth: true
                Text { text: "Address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }
            }

            Text { text: "Register type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
            ComboBox {
                id: dRegType; Layout.fillWidth: true
                model: ["Invalid", "Discrete Inputs", "Coils", "Input Registers", "Holding Registers"]
            }

            // Data type & format — hidden for DI/DO (always bool/1-bit)
            Text { text: "Data type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: isAnalog }
            ComboBox { id: dDataType; model: ["int16", "uint16", "int32", "uint32", "float32"]; Layout.fillWidth: true; visible: isAnalog }

            Text { text: "Endian format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: isAnalog }
            ComboBox { id: dDataFmt; model: ["AB", "BA", "ABCD", "CDAB", "BADC", "DCBA"]; Layout.fillWidth: true; visible: isAnalog }
        }
    }
}
