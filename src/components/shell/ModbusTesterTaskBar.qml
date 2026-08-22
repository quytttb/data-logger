pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

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
                spacing: AppTheme.spacingS
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
                    text: TesterController.isConnecting ? qsTr("Connecting…")
                        : MonitorController.isPolling ? qsTr("Monitor is running")
                        : TesterController.isConnected ? qsTr("Disconnect") : qsTr("Connect")
                    font.pixelSize: AppTypography.labelMedium.pixelSize
                    font.bold: true
                    fillColor: TesterController.isConnected ? AppColors.error : AppColors.primaryColor
                    onClicked: {
                        if (root.testerView)
                            root.testerView.connectOrDisconnect()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                AppButton {
                    Layout.preferredHeight: 44
                    visible: TesterController.isConnected
                    text: qsTr("Save new sensor")
                    font.pixelSize: AppTypography.labelSmall.pixelSize
                    font.bold: true
                    fillColor: AppColors.success
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
                spacing: AppTheme.spacingS

                // ── Mode Toggle (Read / Write) ──
                RowLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignVCenter

                    AppButton {
                        text: qsTr("Read")
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: AppTypography.labelMedium.pixelSize
                        font.bold: true
                        kind: root.isReadMode ? AppButton.Primary : AppButton.Secondary
                        onClicked: {
                            if (root.testerView && root.testerView.opsItem)
                                root.testerView.opsItem.isReadMode = true
                        }
                    }
                    AppButton {
                        text: qsTr("Write")
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: AppTypography.labelMedium.pixelSize
                        font.bold: true
                        kind: !root.isReadMode ? AppButton.Primary : AppButton.Secondary
                        fillColor: AppColors.warning
                        onClicked: {
                            if (root.testerView && root.testerView.opsItem)
                                root.testerView.opsItem.isReadMode = false
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: AppColors.outlineVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Label {
                        text: qsTr("Hide 0")
                        color: AppColors.onSurfaceVariant
                        font.pixelSize: AppTypography.labelSmall.pixelSize
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
                    text: qsTr("Clear table")
                    Layout.preferredHeight: 44
                    font.pixelSize: AppTypography.labelSmall.pixelSize
                    font.bold: true
                    enabled: root.testerView !== null && !TesterController.isScanning
                    fillColor: AppColors.warning
                    onClicked: {
                        if (root.testerView)
                            root.testerView.clearResultsTable()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                AppButton {
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 100
                    font.pixelSize: AppTypography.labelMedium.pixelSize
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

                    fillColor: {
                        if (root.isReadMode)
                            return TesterController.isScanning ? AppColors.error : AppColors.primaryColor
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
