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

                Button {
                    id: connectBtn
                    Layout.preferredHeight: 44
                    enabled: root.testerView !== null && !TesterController.isConnecting
                    text: TesterController.isConnecting ? "Connecting…"
                        : TesterController.isConnected ? "Disconnect" : "Connect"
                    font.pixelSize: 12
                    font.bold: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: TesterController.isConnecting ? Theme.btnBgDisabled
                             : TesterController.isConnected ? Theme.btnStop : Theme.accent
                        opacity: connectBtn.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: connectBtn.text
                        font: connectBtn.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        if (root.testerView)
                            root.testerView.connectOrDisconnect()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    id: saveSensorBtn
                    Layout.preferredHeight: 44
                    visible: TesterController.isConnected
                    text: "Save new sensor"
                    font.pixelSize: 11
                    font.bold: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.btnStart
                        opacity: saveSensorBtn.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: saveSensorBtn.text
                        font: saveSensorBtn.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
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

                    Button {
                        id: readModeBtn
                        text: "Read"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: root.isReadMode ? AppColors.primaryColor : AppColors.surface
                            border.color: AppColors.outlineVariant
                            border.width: 1
                        }
                        contentItem: Text {
                            text: readModeBtn.text
                            font: readModeBtn.font
                            color: root.isReadMode ? AppColors.onPrimary : AppColors.onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (root.testerView && root.testerView.opsItem)
                                root.testerView.opsItem.isReadMode = true
                        }
                    }
                    Button {
                        id: writeModeBtn
                        text: "Write"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: !root.isReadMode ? AppColors.warning : AppColors.surface
                            border.color: AppColors.outlineVariant
                            border.width: 1
                        }
                        contentItem: Text {
                            text: writeModeBtn.text
                            font: writeModeBtn.font
                            color: !root.isReadMode ? AppColors.primaryText : AppColors.onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
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

                Button {
                    id: clearBtn
                    text: "Clear table"
                    Layout.preferredHeight: 44
                    font.pixelSize: 11
                    font.bold: true
                    enabled: root.testerView !== null && !TesterController.isScanning
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.btnClear
                        opacity: clearBtn.pressed ? 0.8 : 1.0
                    }
                    contentItem: Text {
                        text: clearBtn.text
                        font: clearBtn.font
                        color: Theme.btnClearText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                    onClicked: {
                        if (root.testerView)
                            root.testerView.clearResultsTable()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    id: actionBtn
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

                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: {
                            if (!actionBtn.enabled) return Theme.btnBgDisabled;
                            if (root.isReadMode) {
                                return TesterController.isScanning ? Theme.btnStop : Theme.accent
                            } else {
                                return AppColors.warning
                            }
                        }
                        opacity: actionBtn.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: actionBtn.text
                        font: actionBtn.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
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
