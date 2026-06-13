import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

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

        // Nửa trái: kết nối — luôn căn trái, độ rộng cố định 50% không ảnh hưởng nửa phải
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
                    visible: testerController.isConnecting
                    running: testerController.isConnecting
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    Layout.preferredHeight: 44
                    enabled: testerView && !testerController.isConnecting
                    text: testerController.isConnecting ? "Connecting…"
                        : testerController.isConnected ? "Disconnect" : "Connect"
                    font.pixelSize: 12
                    font.bold: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: testerController.isConnecting ? Theme.btnBgDisabled
                             : testerController.isConnected ? Theme.btnStop : Theme.accent
                        opacity: parent.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        if (testerView)
                            testerView.connectOrDisconnect()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    Layout.preferredHeight: 44
                    visible: testerController.isConnected
                    text: "Save new sensor"
                    font.pixelSize: 11
                    font.bold: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.btnStart
                        opacity: parent.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        if (testerView)
                            testerView.openSaveSensorInSettings()
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
                        text: "Read"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: isReadMode ? Theme.accent : Theme.bgDeep
                            border.color: Theme.borderDefault
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: isReadMode ? "white" : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (testerView && testerView.opsItem)
                                testerView.opsItem.isReadMode = true
                        }
                    }
                    Button {
                        text: "Write"
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 70
                        font.pixelSize: 12
                        font.bold: true
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: !isReadMode ? "#e67e22" : Theme.bgDeep
                            border.color: Theme.borderDefault
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: !isReadMode ? "white" : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (testerView && testerView.opsItem)
                                testerView.opsItem.isReadMode = false
                        }
                    }
                }

                // Separator 
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: Theme.borderDefault
                    Layout.alignment: Qt.AlignVCenter
                }

                // Toggle lọc hàng có giá trị 0
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
                            if (testerView)
                                testerView.hideZeros = checked
                        }
                    }
                }

                Button {
                    id: clearBtn
                    text: "Clear table"
                    Layout.preferredHeight: 44
                    font.pixelSize: 11
                    font.bold: true
                    enabled: testerView && !testerController.isScanning
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.btnClear
                        opacity: parent.pressed ? 0.8 : 1.0
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
                        if (testerView)
                            testerView.clearResultsTable()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }



                Button {
                    id: actionBtn
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 100
                    font.pixelSize: 12
                    font.bold: true
                    enabled: testerView && !testerController.isStopping
                    
                    // Logic đổi text theo chế độ Read / Write
                    text: {
                        if (isReadMode) {
                            return testerController.isStopping ? "Stopping…"
                                 : testerController.isScanning ? "Stop scan" : "Scan range"
                        } else {
                            return "Write"
                        }
                    }
                    
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: {
                            if (!actionBtn.enabled) return Theme.btnBgDisabled;
                            if (isReadMode) {
                                return testerController.isScanning ? Theme.btnStop : Theme.accent
                            } else {
                                return "#e67e22" // Màu cam cho nút Write
                            }
                        }
                        opacity: parent.pressed ? 0.75 : 1.0
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
                        if (testerView) {
                            if (isReadMode) {
                                testerView.toggleScan()
                            } else {
                                testerView.performWrite()
                            }
                        }
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                BusyIndicator {
                    visible: isReadMode && testerController.isStopping
                    running: isReadMode && testerController.isStopping
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
