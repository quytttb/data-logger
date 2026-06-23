import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.VirtualKeyboard
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components
import "."

ApplicationWindow {
    id: root
    visible: true

    Material.theme: AppTheme.materialTheme
    Material.primary: AppTheme.primary
    Material.accent: AppTheme.accent
    palette.buttonText: AppColors.buttonText

    function syncModbusTaskBarRef() {
        tabContent.syncModbusTaskBar(headerChrome.modbusTbLoader.item)
    }

    function handleNavigateToAddSensor(data) {
        root.currentTab = 3  // Switch to Settings tab
        Qt.callLater(function() {
            tabContent.setSettingsReturnMainTab(4)  // Return to Tester tab
            tabContent.openSettingsAddSensorWithData(data)
        })
    }
    // Kích thước fallback cho màn hình 7" (1024x600) khi không chạy fullscreen
    width: 1024
    height: 600
    title: "Data Logger"
    color: AppColors.surface
    // Kiosk mode: luôn toàn màn hình trên EGLFS, không thanh tiêu đề / không thoát
    visibility: Window.FullScreen

    // ── Navigation state ─────────────────────────────────────────────────
    property int currentTab: 0
    property int scanProgCur: 0
    property int scanProgTot: 0

    onCurrentTabChanged: {
        // Auto-clear history results when leaving the history tab
        if (currentTab !== 1) HistoryViewModel.clear()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        AppSideBar {
            Layout.preferredWidth: AppTheme.railWidth
            Layout.fillHeight: true
            currentTab: root.currentTab
            onSelectTab: function (i) {
                // If leaving Settings while Add/Edit form is open, cancel it
                if (root.currentTab === 3 && i !== 3) {
                    if (tabContent.settingsTabIndex() === 4) {
                        tabContent.closeSettingsSensorForm()
                    }
                }
                root.currentTab = i
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            MainHeaderChrome {
                id: headerChrome
                Layout.fillWidth: true
                currentTab: root.currentTab
                scanProgCur: root.scanProgCur
                scanProgTot: root.scanProgTot
                appRoot: root
                tabContent: tabContent
            }

            MainTabContent {
                id: tabContent
                currentTab: root.currentTab
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Connections {
        target: tabContent
        function onTesterNavigateToAddSensor(data) {
            root.handleNavigateToAddSensor(data)
        }
        function onSettingsRequestMainTabChange(tabIndex) {
            root.currentTab = tabIndex
        }
    }

    Component.onCompleted: root.syncModbusTaskBarRef()

    Connections {
        target: TesterController
        function onScanProgress(current, total) {
            root.scanProgCur = current
            root.scanProgTot = total
        }
        function onScanResult(result) {
            if (result.found !== undefined) {
                root.scanProgCur = result.slave_id || 0
            }
        }
        function onScanningChanged() {
            if (!TesterController.isScanning) {
                root.scanProgCur = 0
                root.scanProgTot = 0
            }
        }
    }

    function notifyMessage(title, body) {
        const t = (title || "").toLowerCase()
        const semantic = (t === "success" || t === "ok") ? "success"
                         : (t === "error" || t === "validation error") ? "error"
                         : (t === "warning") ? "warning" : "info"
        AppNotifier.show(body || title, semantic, { detailTitle: title, detailText: body })
    }

    AppToastHost { id: appToastHost }
    MessageDetailDialog { id: messageDetailDialog }

    Connections {
        target: MonitorController
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }
    Connections {
        target: HistoryViewModel
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }
    Connections {
        target: SettingsController
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }
    Connections {
        target: SensorListModel
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }
    Connections {
        target: TesterController
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }
    Connections {
        target: ReportController
        function onMessageSent(t, m) { root.notifyMessage(t, m) }
    }

    // On-screen keyboard for touch input. Slides up from the bottom whenever a
    // text field gains focus and slides back down on blur.
    InputPanel {
        id: inputPanel
        z: 999
        x: 0
        y: root.height
        width: root.width

        states: State {
            name: "visible"
            when: inputPanel.active
            PropertyChanges {
                target: inputPanel
                y: root.height - inputPanel.height
            }
        }
        transitions: Transition {
            from: ""
            to: "visible"
            reversible: true
            NumberAnimation {
                properties: "y"
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }
    }
}
