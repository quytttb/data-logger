import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."

ApplicationWindow {
    id: root
    visible: true

    function syncModbusTaskBarRef() {
        if (modbusTbLoader.item)
            modbusTbLoader.item.testerView = loaderTester.item
    }
    // Kích thước fallback khi thoát fullscreen (F11 / Alt+F4 vẫn đóng được tùy WM)
    width: 1024
    height: 600
    title: qsTr("Data Logger")
    color: Theme.bgDeep
    // Toàn màn hình khi mở: che taskbar + không thanh tiêu đề (decoration)
    visibility: Window.FullScreen

    // ── Navigation state ─────────────────────────────────────────────────
    property int currentTab: 0
    property int scanProgCur: 0
    property int scanProgTot: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header + gạch dưới + (tuỳ chọn) thanh tiến độ — khóa chiều cao để ProgressBar Material không làm RowLayout content nuốt hết màn hình
        ColumnLayout {
            id: headerChrome
            Layout.fillWidth: true
            Layout.preferredHeight: 64 + 1 + ((root.currentTab === 3 && testerController.isScanning) ? 10 : 0)
            Layout.maximumHeight: Layout.preferredHeight
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.minimumHeight: 64
                Layout.maximumHeight: 64
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    color: Theme.bgPanel

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        Image {
                            height: 40
                            width: height
                            fillMode: Image.PreserveAspectFit
                            source: (typeof appIconUrl === "string" && appIconUrl.length > 0) ? appIconUrl : ""
                            visible: source.toString().length > 0
                            asynchronous: true
                        }

                        Text {
                            text: "Data Logger"
                            font.pixelSize: 15
                            font.weight: Font.Black
                            font.letterSpacing: 1
                            color: Theme.accentText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bgDeep

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Loader {
                            id: modbusTbLoader
                            Layout.fillWidth: root.currentTab === 3
                            Layout.fillHeight: true
                            active: root.currentTab === 3
                            visible: root.currentTab === 3
                            source: "ModbusTesterTaskBar.qml"
                            onLoaded: root.syncModbusTaskBarRef()
                            onVisibleChanged: {
                                if (visible)
                                    Qt.callLater(root.syncModbusTaskBarRef)
                            }
                        }

                        Loader {
                            id: monitorTbLoader
                            Layout.fillWidth: root.currentTab === 0
                            Layout.fillHeight: true
                            active: root.currentTab === 0
                            visible: root.currentTab === 0
                            source: "MonitorTaskBar.qml"
                        }

                        Label {
                            visible: root.currentTab === 2
                            text: qsTr("Settings")
                            font.pixelSize: 15
                            font.bold: true
                            color: Theme.accentText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: root.currentTab === 2
                        }

                        Loader {
                            Layout.fillWidth: root.currentTab === 1
                            Layout.fillHeight: true
                            active: root.currentTab === 1
                            source: "HistoryTaskBar.qml"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.bgSeparator
            }

            // Tiến độ quét: sát cạnh dưới header, chỉ cột phải (sau 200px logo)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: (root.currentTab === 3 && testerController.isScanning) ? 10 : 0
                Layout.maximumHeight: Layout.preferredHeight
                visible: Layout.preferredHeight > 0
                spacing: 0

                Item {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    Layout.maximumHeight: 8
                    clip: true

                    ProgressBar {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        height: 6
                        from: 0
                        to: 100
                        value: root.scanProgTot > 0 ? (root.scanProgCur / root.scanProgTot) * 100 : 0
                        indeterminate: testerController.isScanning && root.scanProgTot <= 0
                    }
                }
            }
        }

        // ── Sidebar + Content ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Sidebar (không lặp logo — đã ở header) ───────────────────
            Rectangle {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                color: Theme.bgPanel

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Nav — Column + Repeater (delegate rộng = sidebar; tránh Repeater trực tiếp trong ColumnLayout)
                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: 4

                            delegate: ItemDelegate {
                                id: navDelegate
                                width: parent.width
                                implicitHeight: 56
                                required property int index
                                readonly property int tabIdx: index
                                highlighted: root.currentTab === tabIdx
                                padding: 0

                                background: Rectangle {
                                    anchors.fill: parent
                                    color: root.currentTab === navDelegate.tabIdx ? Theme.bgSeparator
                                         : parent.hovered ? Qt.rgba(1,1,1,0.04) : "transparent"

                                    Rectangle {
                                        width: 4
                                        height: parent.height
                                        color: root.currentTab === navDelegate.tabIdx ? Theme.accent : "transparent"
                                    }
                                }

                                contentItem: Text {
                                    text: [qsTr("Monitor"), qsTr("History"), qsTr("Settings"), qsTr("Modbus tester")][navDelegate.index]
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: root.currentTab === navDelegate.tabIdx ? Theme.textPrimary : Theme.textSecondary
                                    leftPadding: 20
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: root.currentTab = navDelegate.tabIdx
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // ── Thoát ứng dụng (khi fullscreen không có nút đóng cửa sổ) ──
                    Button {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.bottomMargin: 8
                        implicitHeight: 44
                        text: qsTr("Exit")
                        font.pixelSize: 13
                        font.weight: Font.Bold

                        background: Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: parent.down ? Qt.darker(Theme.btnStop, 1.15)
                                 : parent.hovered ? Qt.lighter(Theme.btnStop, 1.08) : Theme.btnStop
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: Qt.quit()
                    }

                    // ── Status bar ───────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: Theme.bgDeep

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 3

                            Text {
                                id: clockLabel
                                text: Qt.formatDateTime(new Date(), "dd/MM/yyyy  HH:mm:ss")
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.textSecondary
                            }

                            Text {
                                text: monitorController.statusText
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: {
                                    var m = monitorController.statusMode;
                                    if (m === 1) return Theme.statusOk;
                                    if (m === 2) return Theme.statusErr;
                                    return Theme.textSecondary;
                                }
                            }

                            RowLayout {
                                spacing: 5
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: {
                                        if (!reportController.isRunning) return Theme.textSecondary;
                                        var s = reportController.lastStatus;
                                        if (s.indexOf("FAIL") >= 0 || s.indexOf("ERROR") >= 0) return Theme.statusErrBright;
                                        if (s.indexOf("OK") >= 0) return Theme.statusOk;
                                        return Theme.accentText;
                                    }
                                }
                                Text {
                                    text: reportController.isRunning
                                        ? (reportController.pendingCount > 0
                                            ? qsTr("FTP (%1 pending)").arg(reportController.pendingCount)
                                            : "FTP")
                                        : qsTr("FTP off")
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }
                }
            }

            // ── Content Area — Lazy Loader ────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: loaderTester
                    anchors.fill: parent
                    // Load khi lần đầu vào tab, giữ trong RAM khi chuyển tab khác
                    active: root.currentTab === 3 || loaderTester.item !== null
                    visible: root.currentTab === 3
                    source: "TesterView.qml"
                }

                Loader {
                    id: loaderMonitor
                    anchors.fill: parent
                    active: root.currentTab === 0 || loaderMonitor.item !== null
                    visible: root.currentTab === 0
                    source: "MonitorView.qml"
                }

                Loader {
                    id: loaderHistory
                    anchors.fill: parent
                    active: root.currentTab === 1 || loaderHistory.item !== null
                    visible: root.currentTab === 1
                    source: "HistoryView.qml"
                }

                Loader {
                    id: loaderSettings
                    anchors.fill: parent
                    active: root.currentTab === 2 || loaderSettings.item !== null
                    visible: root.currentTab === 2
                    source: "SettingsView.qml"
                }
            }
        }
    }

    Connections {
        target: loaderTester
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

    // Clock timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "dd/MM/yyyy  HH:mm:ss")
    }
}
