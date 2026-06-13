import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import DataLogger.Theme
import DataLogger.Components
import "."

ApplicationWindow {
    id: root
    visible: true

    function syncModbusTaskBarRef() {
        if (headerChrome.modbusTbLoader.item)
            headerChrome.modbusTbLoader.item.testerView = tabContent.loaderTester.item
    }

    function handleNavigateToAddSensor(data) {
        root.currentTab = 3  // Switch to Settings tab
        // Wait a frame for the settings loader to activate, then call openAddSensorWithData
        Qt.callLater(function() {
            if (tabContent.loaderSettings.item) {
                tabContent.loaderSettings.item.returnMainTab = 4  // Return to Tester tab
                tabContent.loaderSettings.item.openAddSensorWithData(data)
            }
        })
    }
    // Kích thước fallback khi thoát fullscreen (F11 / Alt+F4 vẫn đóng được tùy WM)
    width: 1024
    height: 600
    title: "Data Logger"
    color: Theme.bgDeep
    // Toàn màn hình khi mở: che taskbar + không thanh tiêu đề (decoration)
    // Tạm thời tắt — bật lại: bỏ comment dòng dưới
    visibility: Window.FullScreen

    // ── Navigation state ─────────────────────────────────────────────────
    property int currentTab: 0
    property int scanProgCur: 0
    property int scanProgTot: 0

    onCurrentTabChanged: {
        // Auto-clear history results when leaving the history tab
        if (currentTab !== 1) historyController.clear()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        MainHeaderChrome {
            id: headerChrome
            Layout.fillWidth: true
            currentTab: root.currentTab
            scanProgCur: root.scanProgCur
            scanProgTot: root.scanProgTot
            appRoot: root
        }

        // ── Sidebar + Content ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            AppSideBar {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                currentTab: root.currentTab
                onSelectTab: function (i) {
                    // If leaving Settings while Add/Edit form is open, cancel it
                    if (root.currentTab === 3 && i !== 3) {
                        if (tabContent.loaderSettings.item && tabContent.loaderSettings.item.settingsTabIndex === 4) {
                            tabContent.loaderSettings.item.closeSensorForm()
                        }
                    }
                    root.currentTab = i
                }
            }

            MainTabContent {
                id: tabContent
                currentTab: root.currentTab
            }
        }
    }

    Connections {
        target: tabContent.loaderTester
        function onLoaded() {
            root.syncModbusTaskBarRef()
            if (tabContent.loaderTester.item)
                tabContent.loaderTester.item.navigateToAddSensor.connect(root.handleNavigateToAddSensor)
        }
    }

    Connections {
        target: tabContent.loaderSettings
        function onLoaded() {
            if (tabContent.loaderSettings.item)
                tabContent.loaderSettings.item.requestMainTabChange.connect(function(tabIndex) {
                    root.currentTab = tabIndex
                })
        }
    }

    Connections {
        target: testerController
        function onScanResult(result) {
            // Update progress indicator for slave scanning
            if (result.found !== undefined) {
                root.scanProgCur = result.slave_id || 0
            }
        }
    }
}
