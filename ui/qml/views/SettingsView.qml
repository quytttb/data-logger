import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../components"
import "../shell"

Rectangle {
    id: settingsRoot
    color: "transparent"
    anchors.fill: parent

    property int settingsTabIndex: 0
    property bool isConfigChanged: false
    property bool hasSelectedSensor: sensorsTab.listView.currentIndex >= 0
    property bool isAddMode: true
    property int editSensorId: -1
    property int sensorSubTabIndex: 0
    property int returnMainTab: -1  // -1 = stay in Settings; >=0 = navigate to that main tab after Save/Cancel
    property bool hasSelectedDio: sensorForm.hasSelectedDio
    property string sensorType: sensorForm.sensorType

    signal requestMainTabChange(int tabIndex)

    // Signals bound to TaskBar
    function saveConfig() {
        settingsController.save_config()
        isConfigChanged = false
        if (generalTab) generalTab.configChanged = false
        if (connectionTab) connectionTab.configChanged = false
        if (serverTab) serverTab.configChanged = false
        // toastPopup is handled by messageSent from controller now, but we can keep it if needed.
    }

    function cancelConfig() {
        settingsController.load_config() // Reload from DB
        isConfigChanged = false
        if (generalTab) generalTab.configChanged = false
        if (connectionTab) connectionTab.configChanged = false
        if (serverTab) serverTab.configChanged = false
    }

    function openAddSensor() {
        isAddMode = true
        editSensorId = -1
        returnMainTab = -1
        sensorSubTabIndex = 0
        sensorForm.resetForm()
        settingsTabIndex = 4
    }

    // Pre-fill Add Sensor form with data from Modbus Tester
    function openAddSensorWithData(data) {
        isAddMode = true
        editSensorId = -1
        sensorForm.resetForm()

        if (data.slaveId !== undefined) sensorForm.slaveId.value = data.slaveId
        if (data.registerAddress !== undefined) sensorForm.registerAddress.value = data.registerAddress
        if (data.registerType !== undefined) {
            var rtIdx = sensorForm.registerType.model.indexOf(data.registerType)
            if (rtIdx >= 0) sensorForm.registerType.currentIndex = rtIdx
        }
        if (data.dataType !== undefined) {
            var dtIdx = sensorForm.dataType.model.indexOf(data.dataType)
            if (dtIdx >= 0) sensorForm.dataType.currentIndex = dtIdx
        }
        if (data.dataFormat !== undefined) {
            var dfIdx = sensorForm.dataFormat.model.indexOf(data.dataFormat)
            if (dfIdx >= 0) sensorForm.dataFormat.currentIndex = dfIdx
        }

        sensorSubTabIndex = 0
        settingsTabIndex = 4
    }

    function editSelectedSensor() {
        if (sensorsTab.listView.currentIndex < 0) return
        var s = sensorModel.get_sensor(sensorsTab.listView.currentIndex)
        if (!s || !s.sensorId) return

        isAddMode = false
        editSensorId = s.sensorId
        returnMainTab = -1
        var ui = settingsController.coefficientUiState(s.coefficient)
        sensorForm.loadData(s, ui)
        sensorForm.dioRepeaterRef.model = sensorModel.get_analog_links(editSensorId)
        // Populate DI/DO dropdowns for attach form (only meaningful for ANALOG sensors)
        if (s.sensorType === "ANALOG") {
            sensorForm.loadLinks(
                sensorModel.list_di_sensors(),
                sensorModel.list_do_sensors(editSensorId))
        }
        sensorSubTabIndex = 0
        settingsTabIndex = 4
    }

    function deleteSelectedSensor() {
        if (sensorsTab.listView.currentIndex < 0) return
        var s = sensorModel.get_sensor(sensorsTab.listView.currentIndex)
        if (!s || !s.sensorId) return

        var msg = "Delete sensor \"" + s.name + "\"?"
        settingsPopup.showConfirm(
            "Confirm delete",
            msg,
            function() { sensorModel.remove_sensor(s.sensorId) },
            "Delete",
            Theme.btnStop
        )
    }

    function saveSensorForm() {
        var d = sensorForm.getFormData()
        var coeff = settingsController.buildCoefficientJson(
            d.scalingModeIndex, d.coeffJson,
            d.scalingModeIndex === 1 ? d.linearA : d.rawMin,
            d.scalingModeIndex === 1 ? d.linearB : d.rawMax,
            d.scaleMin, d.scaleMax
        )
        if (coeff.length === 0) return

        if (isAddMode) {
            sensorModel.add_sensor(d.name, d.unit, d.slaveId, d.registerAddress,
                d.registerType, d.dataType, d.dataFormat,
                coeff, d.pollInterval, d.reportIndex, d.active,
                d.minThreshold, d.maxThreshold)
        } else {
            sensorModel.update_sensor(editSensorId, d.name, d.unit,
                d.slaveId, d.registerAddress, d.registerType, d.dataType,
                d.dataFormat, coeff, d.pollInterval, d.reportIndex,
                d.active, d.minThreshold, d.maxThreshold)
        }
        _navigateBack()
    }

    function _refreshLinks() {
        sensorForm.dioRepeaterRef.model = sensorModel.get_analog_links(editSensorId)
        sensorForm.loadLinks(
            sensorModel.list_di_sensors(),
            sensorModel.list_do_sensors(editSensorId))
    }

    function closeSensorForm() {
        _navigateBack()
    }

    function deleteSelectedDio() {
        sensorForm.deleteSelectedDio()
    }

    function _navigateBack() {
        if (returnMainTab >= 0) {
            var tab = returnMainTab
            returnMainTab = -1
            settingsTabIndex = 3
            requestMainTabChange(tab)
        } else {
            settingsTabIndex = 3
        }
    }

    MessagePopup {
        id: settingsPopup
    }

    ToastPopup {
        id: toastPopup
    }

    Connections {
        target: settingsController
        function onMessageSent(t, m) { 
            if (t.toLowerCase() === "success") toastPopup.showToast(t, m)
            else settingsPopup.showMessage(t, m)
        }
    }

    Connections {
        target: sensorModel
        function onMessageSent(t, m) { 
            if (t.toLowerCase() === "success") toastPopup.showToast(t, m)
            else settingsPopup.showMessage(t, m)
        }
    }

    Component.onCompleted: { sensorModel.refresh() }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 0

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: settingsRoot.settingsTabIndex

            // ── Tab 0: General ──
            SettingsGeneralTab {
                id: generalTab
                Layout.fillWidth: true; Layout.fillHeight: true
                settingsMessagePopup: settingsPopup
                onConfigChangedChanged: { if (configChanged) settingsRoot.isConfigChanged = true }
            }

            // ── Tab 1: Connection ──
            SettingsConnectionTab {
                id: connectionTab
                Layout.fillWidth: true; Layout.fillHeight: true
                onConfigChangedChanged: { if (configChanged) settingsRoot.isConfigChanged = true }
            }

            // ── Tab 2: Server ──
            SettingsServerTab {
                id: serverTab
                Layout.fillWidth: true; Layout.fillHeight: true
                onConfigChangedChanged: { if (configChanged) settingsRoot.isConfigChanged = true }
            }

            // ── Tab 3: Sensors List ──
            SettingsSensorsTab {
                id: sensorsTab
                Layout.fillWidth: true; Layout.fillHeight: true
                onSensorDoubleClicked: settingsRoot.editSelectedSensor()
            }

            // ── Tab 4: Add/Edit Sensor Form ──
            SensorConfigForm {
                id: sensorForm
                Layout.fillWidth: true; Layout.fillHeight: true
                isTesterMode: false
                isAddMode: settingsRoot.isAddMode
                editSensorId: settingsRoot.editSensorId
                sensorSubTabIndex: settingsRoot.sensorSubTabIndex
                onAttachDiRequested: function(diSensorId, diType) {
                    sensorModel.attach_di(settingsRoot.editSensorId, diSensorId, diType)
                    settingsRoot._refreshLinks()
                }
                onAttachDoRequested: function(doSensorId, trigMax, trigMin) {
                    sensorModel.attach_do(settingsRoot.editSensorId, doSensorId, trigMax, trigMin)
                    settingsRoot._refreshLinks()
                }
                onRemoveDioRequested: function(linkId) {
                    sensorModel.detach_link(linkId)
                    settingsRoot._refreshLinks()
                }
                onUpdateLinkDiTypeRequested: function(linkId, diType) {
                    sensorModel.update_link_di_type(linkId, diType)
                }
                onUpdateLinkDoTriggersRequested: function(linkId, trigMax, trigMin) {
                    sensorModel.update_link_do_triggers(linkId, trigMax, trigMin)
                }
            }
        }
    }
}
