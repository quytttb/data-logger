import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: sideBarRoot
    implicitWidth: 200
    color: Theme.bgPanel

    property int currentTab: 0
    signal selectTab(int index)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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
                    highlighted: sideBarRoot.currentTab === tabIdx
                    padding: 0

                    background: Rectangle {
                        anchors.fill: parent
                        color: sideBarRoot.currentTab === navDelegate.tabIdx ? Theme.bgSeparator
                             : parent.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                        Rectangle {
                            width: 4
                            height: parent.height
                            color: sideBarRoot.currentTab === navDelegate.tabIdx ? Theme.accent : "transparent"
                        }
                    }

                    text: ["Monitor", "History", "Settings", "Modbus tester"][navDelegate.index]
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    palette.buttonText: sideBarRoot.currentTab === navDelegate.tabIdx ? Theme.textPrimary : Theme.textSecondary
                    icon.source: ["../../assets/icons/monitor.svg", "../../assets/icons/history.svg", "../../assets/icons/settings.svg", "../../assets/icons/tester.svg"][navDelegate.index]
                    icon.color: sideBarRoot.currentTab === navDelegate.tabIdx ? Theme.textPrimary : Theme.textSecondary
                    icon.width: 18
                    icon.height: 18
                    spacing: 12
                    leftPadding: 16

                    onClicked: sideBarRoot.selectTab(navDelegate.tabIdx)
                }
            }
        }

        Item { Layout.fillHeight: true }

        Button {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            implicitHeight: 44
            text: "Exit"
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
                        if (m === 1)
                            return Theme.statusOk;
                        if (m === 2)
                            return Theme.statusErr;
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
                            if (!reportController.isRunning)
                                return Theme.textSecondary;
                            var s = reportController.lastStatus;
                            if (s.indexOf("FAIL") >= 0 || s.indexOf("ERROR") >= 0)
                                return Theme.statusErrBright;
                            if (s.indexOf("OK") >= 0)
                                return Theme.statusOk;
                            return Theme.accentText;
                        }
                    }
                    Text {
                        text: reportController.isRunning
                            ? (reportController.pendingCount > 0
                                ? "FTP (%1 pending)".arg(reportController.pendingCount)
                                : "FTP")
                            : "FTP off"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "dd/MM/yyyy  HH:mm:ss")
    }
}
