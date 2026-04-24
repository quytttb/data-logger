import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Shared sensor configuration form used by both SettingsView and TesterView.
// This is a "dumb component" — it does NOT call controllers/models directly.
// Parent views call loadData() / resetForm() to populate, and getFormData() to read values.

Item {
    id: root

    // ── Public API ──
    property bool isTesterMode: false  // Hide Poll interval, Report column, Digital I/O in Tester
    property bool isAddMode: true
    property int editSensorId: -1
    property int sensorSubTabIndex: 0

    // Expose for parent to connect Digital I/O adding/removing
    signal addDioFormSubmitted(string ioType, string label, int slave, int addr, bool trigMax, bool trigMin)
    signal removeDioRequested(int dioId)

    // ── Internal refs (aliases for parent access) ──
    property alias sensorName: dName
    property alias sensorUnit: dUnit
    property alias slaveId: dSlave
    property alias registerAddress: dAddr
    property alias registerType: dRegType
    property alias dataType: dDataType
    property alias dataFormat: dDataFmt
    property alias scalingMode: dScalingMode
    property alias linearA: dLinearA
    property alias linearB: dLinearB
    property alias rawMin: dRawMin
    property alias rawMax: dRawMax
    property alias scaleMin: dScaleMin
    property alias scaleMax: dScaleMax
    property alias coeffJson: dCoeffJson
    property alias pollInterval: dPollInterval
    property alias reportIndex: dReportIdx
    property alias activeSwitch: dActive
    property alias minThreshold: dMinThreshold
    property alias maxThreshold: dMaxThreshold
    property alias dioRepeaterRef: dioRepeater

    // ── Public functions ──
    function resetForm() {
        dName.text = ""; dUnit.currentIndex = 0; dSlave.value = 1; dAddr.value = 0
        dRegType.currentIndex = 0; dDataType.currentIndex = 0; dDataFmt.currentIndex = 0
        dScalingMode.currentIndex = 0
        dLinearA.text = "1"; dLinearB.text = "0"
        dRawMin.text = "4000"; dRawMax.text = "20000"; dScaleMin.text = "4"; dScaleMax.text = "20"
        dCoeffJson.text = "{}"
        dPollInterval.value = 3; dReportIdx.value = 0; dActive.checked = true
        dMinThreshold.text = ""; dMaxThreshold.text = ""
    }

    function loadData(s, uiState) {
        dName.text = s.name
        // Set unit ComboBox: try to find in list, otherwise set editText
        var unitIdx = dUnit.find(s.unit)
        if (unitIdx >= 0) dUnit.currentIndex = unitIdx
        else dUnit.editText = s.unit

        dSlave.value = s.slaveId; dAddr.value = s.registerAddress
        dRegType.currentIndex = dRegType.model.indexOf(s.registerType)
        dDataType.currentIndex = dDataType.model.indexOf(s.dataType)
        dDataFmt.currentIndex = dDataFmt.model.indexOf(s.dataFormat)
        
        dScalingMode.currentIndex = Math.min(uiState.mode, dScalingMode.count - 1)
        dLinearA.text = uiState.linearA !== undefined ? String(uiState.linearA) : "1"
        dLinearB.text = uiState.linearB !== undefined ? String(uiState.linearB) : "0"
        dRawMin.text = uiState.rawMin !== undefined ? String(uiState.rawMin) : "4000"
        dRawMax.text = uiState.rawMax !== undefined ? String(uiState.rawMax) : "20000"
        dScaleMin.text = uiState.scaleMin !== undefined ? String(uiState.scaleMin) : "4"
        dScaleMax.text = uiState.scaleMax !== undefined ? String(uiState.scaleMax) : "20"
        dCoeffJson.text = uiState.legacyJson !== undefined ? String(uiState.legacyJson) : "{}"
        
        dPollInterval.value = s.pollInterval || 3
        dReportIdx.value = s.reportIndex; dActive.checked = s.active
        dMinThreshold.text = s.minThreshold !== undefined && s.minThreshold !== "" ? String(s.minThreshold) : ""
        dMaxThreshold.text = s.maxThreshold !== undefined && s.maxThreshold !== "" ? String(s.maxThreshold) : ""
    }

    function getFormData() {
        return {
            name: dName.text,
            unit: dUnit.editText,
            slaveId: dSlave.value,
            registerAddress: dAddr.value,
            registerType: dRegType.currentText,
            dataType: dDataType.currentText,
            dataFormat: dDataFmt.currentText,
            scalingModeIndex: dScalingMode.currentIndex,
            linearA: dLinearA.text,
            linearB: dLinearB.text,
            rawMin: dRawMin.text,
            rawMax: dRawMax.text,
            scaleMin: dScaleMin.text,
            scaleMax: dScaleMax.text,
            coeffJson: dCoeffJson.text,
            pollInterval: dPollInterval.value,
            reportIndex: dReportIdx.value,
            active: dActive.checked,
            minThreshold: dMinThreshold.text,
            maxThreshold: dMaxThreshold.text
        }
    }

    // ── UI ──
    StackLayout {
        id: formStack
        anchors.fill: parent
        currentIndex: root.sensorSubTabIndex

        // ═══════════════════════════════════════════════════════════════
        // TAB 0: Basic Info & Modbus Settings
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            color: Theme.bgPanel; radius: Theme.radiusCard
            border.color: Theme.borderDefault; border.width: 1

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

                    Text { text: "Unit:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        id: dUnit; Layout.fillWidth: true
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

                    Text { text: "Poll interval (s):"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode }
                    SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true; visible: !root.isTesterMode }

                    Text { text: "Report column index:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: !root.isTesterMode }
                    SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true; visible: !root.isTesterMode }
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
                    ComboBox { id: dRegType; model: ["Invalid", "Discrete Inputs", "Coils", "Input Registers", "Holding Registers"]; Layout.fillWidth: true }

                    Text { text: "Data type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox { id: dDataType; model: ["int16", "uint16", "int32", "uint32", "float32"]; Layout.fillWidth: true }

                    Text { text: "Endian format:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox { id: dDataFmt; model: ["AB", "BA", "ABCD", "CDAB"]; Layout.fillWidth: true }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // TAB 1: Scaling & Alarms
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            color: Theme.bgPanel; radius: Theme.radiusCard
            border.color: Theme.borderDefault; border.width: 1

            ColumnLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 20
                spacing: 8

                Text { text: "Scaling & Alarms"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                // Use a 2-column grid for compact threshold + scaling layout
                GridLayout {
                    columns: 4; Layout.fillWidth: true; columnSpacing: 15; rowSpacing: 8

                    Text { text: "Min threshold:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField { id: dMinThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                    Text { text: "Max threshold:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    TextField { id: dMaxThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
                }

                Item { Layout.preferredHeight: 8 }

                Text { text: "Scaling mode:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                ComboBox {
                    id: dScalingMode; Layout.fillWidth: true; Layout.maximumWidth: 400
                    model: ["No scaling (raw value)", "Linear (y = ax + b)", "Two-point mapping", "Advanced (JSON)"]
                }

                StackLayout {
                    Layout.fillWidth: true; currentIndex: dScalingMode.currentIndex
                    Item { implicitHeight: 0 }
                    RowLayout {
                        spacing: 8
                        Text { text: "a:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        TextField { id: dLinearA; Layout.fillWidth: true; text: "1" }
                        Text { text: "b:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        TextField { id: dLinearB; Layout.fillWidth: true; text: "0" }
                    }
                    ColumnLayout {
                        spacing: 6
                        RowLayout {
                            spacing: 8
                            Text { text: "RawMin:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 60 }
                            TextField { id: dRawMin; text: "4000"; Layout.fillWidth: true }
                            Text { text: "Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                            TextField { id: dRawMax; text: "20000"; Layout.fillWidth: true }
                        }
                        RowLayout {
                            spacing: 8
                            Text { text: "ScaleMin:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 60 }
                            TextField { id: dScaleMin; text: "4"; Layout.fillWidth: true }
                            Text { text: "Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                            TextField { id: dScaleMax; text: "20"; Layout.fillWidth: true }
                        }
                    }
                    TextField { id: dCoeffJson; text: "{}"; Layout.fillWidth: true }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // TAB 2: Digital I/O
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            color: Theme.bgPanel; radius: Theme.radiusCard
            border.color: Theme.borderDefault; border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 20
                spacing: 20

                // ── LEFT: Add Form ──
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 12

                    Text { text: "Add Digital I/O"; color: Theme.accentText; font.bold: true; font.pixelSize: 15 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    GridLayout {
                        columns: 2; Layout.fillWidth: true; columnSpacing: 10; rowSpacing: 10

                        Text { text: "Type:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        ComboBox {
                            id: newDioType
                            model: ["DI", "DO"]
                            Layout.fillWidth: true
                        }

                        Text { text: "Label:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        AppTextField { id: newDioLabel; Layout.fillWidth: true; placeholderText: "e.g. Buzzer, Lamp" }

                        Text { text: "Slave ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        SpinBox { id: newDioSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true; editable: true }

                        Text { text: "Address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        SpinBox { id: newDioAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }

                        Text { text: "Trigger on Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: newDioType.currentText === "DO" }
                        Switch { id: newDioTrigMax; checked: true; visible: newDioType.currentText === "DO" }

                        Text { text: "Trigger on Min:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: newDioType.currentText === "DO" }
                        Switch { id: newDioTrigMin; checked: true; visible: newDioType.currentText === "DO" }
                    }

                    Item { Layout.fillHeight: true } // Spacer

                    Button {
                        text: "ADD " + newDioType.currentText
                        Layout.fillWidth: true
                        onClicked: {
                            if (newDioLabel.text.trim() === "") return
                            root.addDioFormSubmitted(newDioType.currentText, newDioLabel.text, newDioSlave.value, newDioAddr.value, newDioTrigMax.checked, newDioTrigMin.checked)
                            // Reset form somewhat
                            newDioLabel.text = ""
                            newDioAddr.value = newDioAddr.value + 1
                        }
                    }
                }

                // Divider
                Rectangle { width: 1; Layout.fillHeight: true; color: Theme.borderDefault }

                // ── RIGHT: List ──
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Configured I/O"; color: Theme.accentText; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true }
                        Text {
                            text: dioRepeater.count > 0 ? dioRepeater.count + " item(s)" : ""
                            color: Theme.textSecondary; font.pixelSize: 13
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    ListView {
                        id: dioListView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 4
                        model: dioRepeater.model

                        delegate: Rectangle {
                            width: dioListView.width; height: 40; radius: 4
                            color: modelData.ioType === "DO" ? "#301010" : "#103010"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 6; spacing: 8
                                Rectangle {
                                    width: 36; height: 24; radius: 4
                                    color: modelData.ioType === "DO" ? Theme.btnStop : Theme.btnStart
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.ioType; color: "#FFF"; font.bold: true; font.pixelSize: 12
                                    }
                                }
                                Text { text: modelData.label; color: Theme.textPrimary; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: "Slave " + modelData.slaveId + " / Addr " + modelData.address; color: Theme.textSecondary; font.pixelSize: 12 }
                                Button {
                                    text: "✕"
                                    Layout.preferredWidth: 32; Layout.preferredHeight: 28
                                    background: Rectangle { color: Theme.bgErrorTint; radius: 4 }
                                    onClicked: root.removeDioRequested(modelData.id)
                                }
                            }
                        }

                        // Empty state
                        Text {
                            visible: dioListView.count === 0
                            anchors.centerIn: parent
                            text: "No digital I/O pins configured.\nUse the form on the left to add DI or DO."
                            color: Theme.textFaint; font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Hidden Repeater to maintain dioRepeater alias compatibility
    Repeater {
        id: dioRepeater
        delegate: Item { visible: false }
    }
}
