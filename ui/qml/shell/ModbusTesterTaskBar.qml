import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// Thanh header Modbus: gọi API trên TesterView (Main.syncModbusTaskBarRef gán từ MainTabContent.loaderTester).
Item {
    id: root
    implicitHeight: 64

    property var testerView: null

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
                            testerView.openSaveSensorDialog()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            color: Theme.borderDefault
            Layout.alignment: Qt.AlignVCenter
        }

        // Nửa phải: quét / xóa bảng — luôn căn phải, vị trí không phụ thuộc độ rộng nhóm kết nối
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                width: implicitWidth

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
                    id: scanHeaderBtn
                    Layout.preferredHeight: 44
                    font.pixelSize: 12
                    font.bold: true
                    enabled: testerView && !testerController.isStopping
                    text: testerController.isStopping ? "Stopping…"
                        : testerController.isScanning ? "Stop scan" : "Scan range"
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: testerController.isStopping ? Theme.btnBgDisabled
                             : testerController.isScanning ? Theme.btnStop : Theme.accent
                        opacity: parent.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: scanHeaderBtn.text
                        font: scanHeaderBtn.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                    onClicked: {
                        if (testerView)
                            testerView.toggleScan()
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                BusyIndicator {
                    visible: testerController.isStopping
                    running: testerController.isStopping
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
