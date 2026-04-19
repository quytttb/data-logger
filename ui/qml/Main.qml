import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."
import "./shell"

ApplicationWindow {
    id: root
    visible: true

    function syncModbusTaskBarRef() {
        if (headerChrome.modbusTbLoader.item)
            headerChrome.modbusTbLoader.item.testerView = tabContent.loaderTester.item
    }
    // Kích thước fallback khi thoát fullscreen (F11 / Alt+F4 vẫn đóng được tùy WM)
    width: 1024
    height: 600
    title: "Data Logger"
    color: Theme.bgDeep
    // Toàn màn hình khi mở: che taskbar + không thanh tiêu đề (decoration)
    visibility: Window.FullScreen

    // ── Navigation state ─────────────────────────────────────────────────
    property int currentTab: 0
    property int scanProgCur: 0
    property int scanProgTot: 0

    onCurrentTabChanged: {
        historyController.setHistoryTabActive(currentTab === 1)
    }
    Component.onCompleted: {
        historyController.setHistoryTabActive(currentTab === 1)
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
        }
    }

    Connections {
        target: testerController
        function onScanProgress(current, total) {
            root.scanProgCur = current
            root.scanProgTot = total
        }
        function onScanningChanged(scanning) {
            if (!scanning) {
                root.scanProgCur = 0
                root.scanProgTot = 0
            }
        }
    }
}
