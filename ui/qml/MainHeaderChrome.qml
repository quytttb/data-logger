import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

ColumnLayout {
    id: headerChromeRoot

    property int currentTab: 0
    property int scanProgCur: 0
    property int scanProgTot: 0
    /// ApplicationWindow — gọi syncModbusTaskBarRef từ Loader taskbar (`var`: Window không phải Item trong QML)
    property var appRoot: null

    property alias modbusTbLoader: modbusTbLoader

    Layout.fillWidth: true
    Layout.preferredHeight: 64 + 1 + ((currentTab === 3 && testerController.isScanning) ? 10 : 0)
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
                    Layout.fillWidth: headerChromeRoot.currentTab === 3
                    Layout.fillHeight: true
                    active: headerChromeRoot.currentTab === 3
                    visible: headerChromeRoot.currentTab === 3
                    source: "ModbusTesterTaskBar.qml"
                    onLoaded: {
                        if (appRoot)
                            appRoot.syncModbusTaskBarRef()
                    }
                    onVisibleChanged: {
                        if (visible && appRoot)
                            Qt.callLater(appRoot.syncModbusTaskBarRef)
                    }
                }

                Loader {
                    id: monitorTbLoader
                    Layout.fillWidth: headerChromeRoot.currentTab === 0
                    Layout.fillHeight: true
                    active: headerChromeRoot.currentTab === 0
                    visible: headerChromeRoot.currentTab === 0
                    source: "MonitorTaskBar.qml"
                }

                Label {
                    visible: headerChromeRoot.currentTab === 2
                    text: "Settings"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.accentText
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: headerChromeRoot.currentTab === 2
                }

                Loader {
                    Layout.fillWidth: headerChromeRoot.currentTab === 1
                    Layout.fillHeight: true
                    active: headerChromeRoot.currentTab === 1
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

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: (headerChromeRoot.currentTab === 3 && testerController.isScanning) ? 10 : 0
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
                value: headerChromeRoot.scanProgTot > 0 ? (headerChromeRoot.scanProgCur / headerChromeRoot.scanProgTot) * 100 : 0
                indeterminate: testerController.isScanning && headerChromeRoot.scanProgTot <= 0
            }
        }
    }
}
