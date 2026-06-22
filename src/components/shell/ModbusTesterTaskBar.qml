import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

// Thanh header Modbus: gọi API trên TesterView (Main.syncModbusTaskBarRef gán từ MainTabContent.loaderTester).
Item {
    id: root
    implicitHeight: 64

    property var testerView: null
    readonly property bool isReadMode: testerView && testerView.opsItem ? testerView.opsItem.isReadMode : true

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Nửa trái: kết nối — luôn căn trái
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                width: implicitWidth

                BusyIndicator {
                    visible: TesterController.isConnecting
                    running: TesterController.isConnecting
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                }

                AppButton {
                    Layout.preferredHeight: 44
                    enabled: root.testerView !== null && !TesterController.isConnecting
                             && !MonitorController.isPolling
                    text: TesterController.isConnecting ? "Connecting…"
                        : MonitorController.isPolling ? "Monitor is running"
                        : TesterController.isConnected ? "Disconnect" : "Connect"
                    font.pixelSize: 12
                    font.bold: true
                    accent: TesterController.isConnected ? Theme.btnStop : Theme.accent
                    onClicked: {
                        if (root.testerView)
                            root.testerView.connectOrDisconnect()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                AppButton {
                    Layout.preferredHeight: 44
                    visible: TesterController.isConnected
                    text: "Save new sensor"
                    font.pixelSize: 11
                    font.bold: true
                    accent: Theme.btnStart
                    onClicked: {
                        if (root.testerView)
                            root.testerView.openSaveSensorInSettings()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // Nửa phải: quét / xóa bảng — luôn căn phải
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // ── Mode Toggle (Read / Write) ──
                RowLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    AppButton {
                        text: "Read"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        variant: root.isReadMode ? "filled" : "outlined"
                        accent: AppColors.primaryColor
                        onClicked: {
                            if (root.testerView && root.testerView.opsItem)
                                root.testerView.opsItem.isReadMode = true
                        }
                    }
                    AppButton {
                        text: "Write"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        variant: !root.isReadMode ? "filled" : "outlined"
                        accent: AppColors.warning
                        onClicked: {
                            if (root.testerView && root.testerView.opsItem)
                                root.testerView.opsItem.isReadMode = false
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: Theme.borderDefault
                    Layout.alignment: Qt.AlignVCenter
                }

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Label {
                        text: "Hide 0"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                    Switch {
                        id: hideZerosSwitch
                        checked: false
                        onCheckedChanged: {
                            if (root.testerView)
                                root.testerView.hideZeros = checked
                        }
                    }
                }

                AppButton {
                    text: "Clear table"
                    Layout.preferredHeight: 44
                    font.pixelSize: 11
                    font.bold: true
                    enabled: root.testerView !== null && !TesterController.isScanning
                    accent: Theme.btnClear
                    onClicked: {
                        if (root.testerView)
                            root.testerView.clearResultsTable()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                AppButton {
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 100
                    font.pixelSize: 12
                    font.bold: true
                    enabled: root.testerView !== null && !TesterController.isStopping

                    text: {
                        if (root.isReadMode) {
                            return TesterController.isStopping ? "Stopping…"
                                 : TesterController.isScanning ? "Stop scan" : "Scan range"
                        } else {
                            return "Write"
                        }
                    }

                    accent: {
                        if (root.isReadMode)
                            return TesterController.isScanning ? Theme.btnStop : Theme.accent
                        return AppColors.warning
                    }
                    onClicked: {
                        if (root.testerView) {
                            if (root.isReadMode) {
                                root.testerView.toggleScan()
                            } else {
                                root.testerView.performWrite()
                            }
                        }
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                BusyIndicator {
                    visible: root.isReadMode && TesterController.isStopping
                    running: root.isReadMode && TesterController.isStopping
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
