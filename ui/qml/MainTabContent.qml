import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: tabContentRoot

    property int currentTab: 0
    property alias loaderTester: loaderTester

    Layout.fillWidth: true
    Layout.fillHeight: true

    Loader {
        id: loaderTester
        anchors.fill: parent
        active: tabContentRoot.currentTab === 3 || loaderTester.item !== null
        visible: tabContentRoot.currentTab === 3
        source: "views/TesterView.qml"
    }

    Loader {
        id: loaderMonitor
        anchors.fill: parent
        active: tabContentRoot.currentTab === 0 || loaderMonitor.item !== null
        visible: tabContentRoot.currentTab === 0
        source: "views/MonitorView.qml"
    }

    Loader {
        id: loaderHistory
        anchors.fill: parent
        active: tabContentRoot.currentTab === 1
        visible: tabContentRoot.currentTab === 1
        source: "views/HistoryView.qml"
    }

    Loader {
        id: loaderSettings
        anchors.fill: parent
        active: tabContentRoot.currentTab === 2 || loaderSettings.item !== null
        visible: tabContentRoot.currentTab === 2
        source: "views/SettingsView.qml"
    }
}
