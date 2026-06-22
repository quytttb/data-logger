import QtQuick
import QtQuick.Layouts

Item {
    id: tabContentRoot

    property int currentTab: 0
    property alias loaderTester: testerView
    property alias loaderSettings: settingsView

    property var _lastSettingsTaskBar: null

    signal testerNavigateToAddSensor(var data)
    signal settingsRequestMainTabChange(int tabIndex)

    Layout.fillWidth: true
    Layout.fillHeight: true

    function connectSettingsTaskBar(taskBar) {
        if (!taskBar || !settingsView)
            return
        if (_lastSettingsTaskBar === taskBar)
            return
        _lastSettingsTaskBar = taskBar

        taskBar.settingsTabIndex = Qt.binding(function() { return settingsView.settingsTabIndex })
        taskBar.isConfigChanged = Qt.binding(function() { return settingsView.isConfigChanged })
        taskBar.hasSelectedSensor = Qt.binding(function() { return settingsView.hasSelectedSensor })
        taskBar.isAddMode = Qt.binding(function() { return settingsView.isAddMode })
        taskBar.sensorSubTabIndex = Qt.binding(function() { return settingsView.sensorSubTabIndex })
        taskBar.hasSelectedDio = Qt.binding(function() { return settingsView.hasSelectedDio })
        taskBar.sensorType = Qt.binding(function() { return settingsView.sensorType || "ANALOG" })

        taskBar.tabSelected.connect(function(idx) { settingsView.settingsTabIndex = idx })
        taskBar.sensorSubTabSelected.connect(function(idx) { settingsView.sensorSubTabIndex = idx })
        taskBar.saveConfig.connect(function() { settingsView.saveConfig() })
        taskBar.cancelConfig.connect(function() { settingsView.cancelConfig() })
        taskBar.addSensor.connect(function() { settingsView.openAddSensor() })
        taskBar.editSelectedSensor.connect(function() { settingsView.editSelectedSensor() })
        taskBar.deleteSelectedSensor.connect(function() { settingsView.deleteSelectedSensor() })
        taskBar.saveSensorForm.connect(function() { settingsView.saveSensorForm() })
        taskBar.cancelSensorForm.connect(function() { settingsView.closeSensorForm() })
        taskBar.deleteSelectedDio.connect(function() { settingsView.deleteSelectedDio() })
    }

    function syncModbusTaskBar(taskBar) {
        if (taskBar)
            taskBar.testerView = testerView
    }

    function openSettingsAddSensorWithData(data) {
        settingsView.openAddSensorWithData(data)
    }

    function settingsTabIndex() {
        return settingsView.settingsTabIndex
    }

    function closeSettingsSensorForm() {
        settingsView.closeSensorForm()
    }

    function setSettingsReturnMainTab(tab) {
        settingsView.returnMainTab = tab
    }

    MonitorView {
        id: monitorView
        anchors.fill: parent
        visible: tabContentRoot.currentTab === 0
    }

    HistoryView {
        id: historyView
        anchors.fill: parent
        visible: tabContentRoot.currentTab === 1
    }

    TrendingView {
        id: trendingView
        anchors.fill: parent
        visible: tabContentRoot.currentTab === 2
    }

    SettingsView {
        id: settingsView
        anchors.fill: parent
        visible: tabContentRoot.currentTab === 3

        Connections {
            target: settingsView
            function onRequestMainTabChange(tabIndex) {
                tabContentRoot.settingsRequestMainTabChange(tabIndex)
            }
        }
    }

    TesterView {
        id: testerView
        anchors.fill: parent
        visible: tabContentRoot.currentTab === 4

        Connections {
            target: testerView
            function onNavigateToAddSensor(data) {
                tabContentRoot.testerNavigateToAddSensor(data)
            }
        }
    }
}
