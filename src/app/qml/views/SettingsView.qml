pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme

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
        SettingsController.saveConfig()
        isConfigChanged = false
        if (generalTab) generalTab.configChanged = false
        if (connectionTab) connectionTab.configChanged = false
        if (serverTab) serverTab.configChanged = false
        if (serverTab && serverTab.transmissionTab)
            serverTab.transmissionTab.configChanged = false
    }

    function cancelConfig() {
        SettingsController.loadConfig() // Reload from DB
        isConfigChanged = false
        if (generalTab) generalTab.configChanged = false
        if (connectionTab) connectionTab.configChanged = false
        if (serverTab) serverTab.configChanged = false
        if (serverTab && serverTab.transmissionTab)
            serverTab.transmissionTab.configChanged = false
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
            let rtIdx = sensorForm.registerType.model.indexOf(data.registerType)
            if (rtIdx >= 0) sensorForm.registerType.currentIndex = rtIdx
        }
        if (data.dataType !== undefined) {
            let dtIdx = sensorForm.dataType.model.indexOf(data.dataType)
            if (dtIdx >= 0) sensorForm.dataType.currentIndex = dtIdx
        }
        if (data.dataFormat !== undefined) {
            let dfIdx = sensorForm.dataFormat.model.indexOf(data.dataFormat)
            if (dfIdx >= 0) sensorForm.dataFormat.currentIndex = dfIdx
        }

        sensorSubTabIndex = 0
        settingsTabIndex = 4
    }

    function editSelectedSensor() {
        if (sensorsTab.listView.currentIndex < 0) return
        var s = SensorListModel.sensorAt(sensorsTab.listView.currentIndex)
        if (!s || !s.sensorId) return

        isAddMode = false
        editSensorId = s.sensorId
        returnMainTab = -1
        var ui = SettingsController.coefficientUiState(s.coefficient)
        sensorForm.loadData(s, ui)
        sensorForm.dioRepeaterRef.model = SensorListModel.get_analog_links(editSensorId)
        // Populate DI/DO dropdowns for attach form (only meaningful for ANALOG sensors)
        if (s.sensorType === "ANALOG") {
            sensorForm.loadLinks(
                SensorListModel.list_di_sensors(),
                SensorListModel.list_do_sensors(editSensorId))
        }
        sensorSubTabIndex = 0
        settingsTabIndex = 4
    }

    function deleteSelectedSensor() {
        if (sensorsTab.listView.currentIndex < 0) return
        var s = SensorListModel.sensorAt(sensorsTab.listView.currentIndex)
        if (!s || !s.sensorId) return

        var msg = "Delete sensor \"" + s.name + "\"?"
        settingsPopup.showConfirm(
            "Confirm delete",
            msg,
            function() { SensorListModel.removeSensor(s.sensorId) },
            "Delete",
            AppColors.error
        )
    }

    function saveSensorForm() {
        var d = sensorForm.getFormData()
        var coeff = SettingsController.buildCoefficientJson(
            d.scalingModeIndex, d.coeffJson,
            d.scalingModeIndex === 1 ? d.linearA : d.rawMin,
            d.scalingModeIndex === 1 ? d.linearB : d.rawMax,
            d.scaleMin, d.scaleMax
        )
        if (coeff.length === 0) return

        var props = {
            "name": d.name, "unit": d.unit, "slaveId": d.slaveId,
            "registerAddress": d.registerAddress, "registerType": d.registerType,
            "dataType": d.dataType, "dataFormat": d.dataFormat,
            "coefficient": coeff, "pollInterval": d.pollInterval,
            "reportIndex": d.reportIndex, "active": d.active,
            "minThreshold": d.minThreshold, "maxThreshold": d.maxThreshold,
            "decimals": d.decimals, "sensorType": d.sensorType,
            "sensorSymbol": d.sensorSymbol
        }
        if (isAddMode) {
            SensorListModel.addSensor(props)
        } else {
            SensorListModel.updateSensor(editSensorId, props)
        }
        _navigateBack()
    }

    function _refreshLinks() {
        sensorForm.dioRepeaterRef.model = SensorListModel.get_analog_links(editSensorId)
        sensorForm.loadLinks(
            SensorListModel.list_di_sensors(),
            SensorListModel.list_do_sensors(editSensorId))
    }

    function closeSensorForm() {
        _navigateBack()
    }

    function deleteSelectedDio() {
        sensorForm.deleteSelectedDio()
    }

    function _navigateBack() {
        if (returnMainTab >= 0) {
            let tab = returnMainTab
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

    // SensorListModel loads from DB in its C++ constructor and stays in sync
    // via modelReset wiring in main.cpp — no explicit refresh needed here.

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
                    SensorListModel.attach_di(settingsRoot.editSensorId, diSensorId, diType)
                    settingsRoot._refreshLinks()
                }
                onAttachDoRequested: function(doSensorId, trigMax, trigMin) {
                    SensorListModel.attach_do(settingsRoot.editSensorId, doSensorId, trigMax, trigMin)
                    settingsRoot._refreshLinks()
                }
                onRemoveDioRequested: function(linkId) {
                    SensorListModel.detach_link(linkId)
                    settingsRoot._refreshLinks()
                }
                onUpdateLinkDiTypeRequested: function(linkId, diType) {
                    SensorListModel.update_link_di_type(linkId, diType)
                }
                onUpdateLinkDoTriggersRequested: function(linkId, trigMax, trigMin) {
                    SensorListModel.update_link_do_triggers(linkId, trigMax, trigMin)
                }
            }
        }
    }
}
