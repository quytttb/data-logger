import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Shared sensor configuration form used by both SettingsView and TesterView.
// This is a "dumb component" — it does NOT call controllers/models directly.
// Parent views call loadData() / resetForm() to populate, and getFormData() to read values.
// Note: It delegates rendering to 3 sub-tabs: Basic, Scaling, and Digital I/O.

Item {
    id: root

    // ── Public API ──
    property bool isTesterMode: false  // Hide Poll interval, Report column, Digital I/O in Tester
    property bool isAddMode: true
    property int editSensorId: -1
    property int sensorSubTabIndex: 0

    // Sensor type for the form (controls visibility of tabs and fields)
    readonly property string sensorType: basicTab.sensorType
    readonly property bool isAnalog: sensorType === "ANALOG"
    readonly property bool isDigital: sensorType === "DI" || sensorType === "DO"

    // Expose for parent to connect Digital I/O adding/removing
    signal addDioFormSubmitted(string ioType, string label, string diType, int slave, int addr, bool trigMax, bool trigMin)
    signal removeDioRequested(int dioId)

    // ── Internal refs (aliases mapped to sub-tabs) ──
    property alias sensorName: basicTab.dName
    property alias sensorUnit: basicTab.dUnit
    property alias slaveId: basicTab.dSlave
    property alias registerAddress: basicTab.dAddr
    property alias registerType: basicTab.dRegType
    property alias dataType: basicTab.dDataType
    property alias dataFormat: basicTab.dDataFmt
    property alias pollInterval: basicTab.dPollInterval
    property alias reportIndex: basicTab.dReportIdx
    property alias activeSwitch: basicTab.dActive
    property alias diType: basicTab.dDiType

    property alias scalingMode: scalingTab.dScalingMode
    property alias linearA: scalingTab.dLinearA
    property alias linearB: scalingTab.dLinearB
    property alias rawMin: scalingTab.dRawMin
    property alias rawMax: scalingTab.dRawMax
    property alias scaleMin: scalingTab.dScaleMin
    property alias scaleMax: scalingTab.dScaleMax
    property alias coeffJson: scalingTab.dCoeffJson
    property alias minThreshold: scalingTab.dMinThreshold
    property alias maxThreshold: scalingTab.dMaxThreshold

    property alias dioRepeaterRef: dioTab.dioRepeaterRef

    // Exposed DIO functions for TaskBar buttons
    property bool hasSelectedDio: dioTab.hasSelectedDio
    function getSelectedDioId() { return dioTab.getSelectedDioId() }
    function editSelectedDio() { dioTab.editSelectedDio() }
    function deleteSelectedDio() { dioTab.deleteSelectedDio() }

    // ── Public functions ──
    function resetForm() {
        basicTab.dName.text = ""; basicTab.dUnit.currentIndex = 0; basicTab.dSlave.value = 1; basicTab.dAddr.value = 0
        basicTab.dRegType.currentIndex = 0; basicTab.dDataType.currentIndex = 0; basicTab.dDataFmt.currentIndex = 0
        scalingTab.dScalingMode.currentIndex = 0
        scalingTab.dLinearA.text = "1"; scalingTab.dLinearB.text = "0"
        scalingTab.dRawMin.text = "4000"; scalingTab.dRawMax.text = "20000"; scalingTab.dScaleMin.text = "4"; scalingTab.dScaleMax.text = "20"
        scalingTab.dCoeffJson.text = "{}"
        basicTab.dPollInterval.value = 3; basicTab.dReportIdx.value = 0; basicTab.dActive.checked = true
        scalingTab.dMinThreshold.text = ""; scalingTab.dMaxThreshold.text = ""
        basicTab.dDiType.currentIndex = 0
    }

    function loadData(s, uiState) {
        basicTab.dName.text = s.name
        // Set unit ComboBox: try to find in list, otherwise set editText
        var unitIdx = basicTab.dUnit.find(s.unit || "")
        if (unitIdx >= 0) basicTab.dUnit.currentIndex = unitIdx
        else basicTab.dUnit.editText = s.unit || ""

        basicTab.dSlave.value = s.slaveId; basicTab.dAddr.value = s.registerAddress
        basicTab.dRegType.currentIndex = basicTab.dRegType.model.indexOf(s.registerType)
        basicTab.dDataType.currentIndex = basicTab.dDataType.model.indexOf(s.dataType)
        basicTab.dDataFmt.currentIndex = basicTab.dDataFmt.model.indexOf(s.dataFormat)
        
        scalingTab.dScalingMode.currentIndex = Math.min(uiState.mode, scalingTab.dScalingMode.count - 1)
        scalingTab.dLinearA.text = uiState.linearA !== undefined ? String(uiState.linearA) : "1"
        scalingTab.dLinearB.text = uiState.linearB !== undefined ? String(uiState.linearB) : "0"
        scalingTab.dRawMin.text = uiState.rawMin !== undefined ? String(uiState.rawMin) : "4000"
        scalingTab.dRawMax.text = uiState.rawMax !== undefined ? String(uiState.rawMax) : "20000"
        scalingTab.dScaleMin.text = uiState.scaleMin !== undefined ? String(uiState.scaleMin) : "4"
        scalingTab.dScaleMax.text = uiState.scaleMax !== undefined ? String(uiState.scaleMax) : "20"
        scalingTab.dCoeffJson.text = uiState.legacyJson !== undefined ? String(uiState.legacyJson) : "{}"
        
        basicTab.dPollInterval.value = s.pollInterval || 3
        basicTab.dReportIdx.value = s.reportIndex; basicTab.dActive.checked = s.active
        scalingTab.dMinThreshold.text = s.minThreshold !== undefined && s.minThreshold !== "" ? String(s.minThreshold) : ""
        scalingTab.dMaxThreshold.text = s.maxThreshold !== undefined && s.maxThreshold !== "" ? String(s.maxThreshold) : ""
    }

    function getFormData() {
        return {
            name: basicTab.dName.text,
            unit: isAnalog ? basicTab.dUnit.editText : "",
            slaveId: basicTab.dSlave.value,
            registerAddress: basicTab.dAddr.value,
            registerType: basicTab.dRegType.currentText,
            dataType: isAnalog ? basicTab.dDataType.currentText : "int16",
            dataFormat: isAnalog ? basicTab.dDataFmt.currentText : "AB",
            scalingModeIndex: isAnalog ? scalingTab.dScalingMode.currentIndex : 0,
            linearA: scalingTab.dLinearA.text,
            linearB: scalingTab.dLinearB.text,
            rawMin: scalingTab.dRawMin.text,
            rawMax: scalingTab.dRawMax.text,
            scaleMin: scalingTab.dScaleMin.text,
            scaleMax: scalingTab.dScaleMax.text,
            coeffJson: scalingTab.dCoeffJson.text,
            pollInterval: basicTab.dPollInterval.value,
            reportIndex: isAnalog ? basicTab.dReportIdx.value : 0,
            active: basicTab.dActive.checked,
            minThreshold: isAnalog ? scalingTab.dMinThreshold.text : "",
            maxThreshold: isAnalog ? scalingTab.dMaxThreshold.text : "",
            sensorType: root.sensorType
        }
    }

    // ── UI ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Sub-tab content
        StackLayout {
            id: formStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.sensorSubTabIndex

            SensorBasicTab {
                id: basicTab
                isTesterMode: root.isTesterMode
            }

            SensorScalingTab {
                id: scalingTab
            }

            SensorDigitalIOTab {
                id: dioTab
                onAddDioFormSubmitted: function(ioType, label, diType, slave, addr, trigMax, trigMin) {
                    root.addDioFormSubmitted(ioType, label, diType, slave, addr, trigMax, trigMin)
                }
                onRemoveDioRequested: function(dioId) {
                    root.removeDioRequested(dioId)
                }
            }
        }
    }
}
