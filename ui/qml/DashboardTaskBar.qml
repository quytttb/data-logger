import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Thanh header Dashboard: start/stop + trạng thái (statusText từ Python tr()).
Item {
    id: root
    implicitHeight: 64

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Button {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 40
            enabled: !dashboardController.isStopping
            text: dashboardController.isStopping ? qsTr("Stopping…")
                : dashboardController.isPolling ? qsTr("Stop acquisition") : qsTr("Start acquisition")
            font.pixelSize: 14
            font.bold: true
            background: Rectangle {
                radius: 8
                color: dashboardController.isStopping ? "#666"
                     : dashboardController.isPolling ? Theme.btnStop : Theme.btnStart
                opacity: parent.pressed ? 0.75 : 1.0
            }
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onClicked: {
                if (dashboardController.isPolling)
                    dashboardController.stop_polling()
                else
                    dashboardController.start_polling()
            }
            Layout.alignment: Qt.AlignVCenter
        }

        BusyIndicator {
            running: dashboardController.isStopping
            visible: dashboardController.isStopping
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            radius: 6
            color: {
                if (!dashboardController.isPolling)
                    return Theme.textSecondary
                return dashboardController.statusMode === 2 ? Theme.statusErrBright : Theme.statusOk
            }
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            text: dashboardController.statusText
            color: Theme.textPrimary
            font.pixelSize: 14
            font.bold: true
            Layout.fillWidth: true
            Layout.minimumWidth: 80
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        Rectangle {
            Layout.preferredWidth: errLabel.implicitWidth + 24
            Layout.preferredHeight: 32
            radius: Theme.radiusSmall
            color: dashboardController.errorCount > 0 ? "#3a2020" : Theme.bgSeparator
            visible: dashboardController.isPolling
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: errLabel
                anchors.centerIn: parent
                text: dashboardController.errorCount > 0
                    ? qsTr("Modbus read errors: %1").arg(dashboardController.errorCount)
                    : qsTr("No read errors")
                color: dashboardController.errorCount > 0 ? Theme.statusErr : Theme.textSecondary
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
