import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Thanh header Monitor: start/stop + trạng thái (statusText từ Python tr()).
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
            enabled: !monitorController.isStopping
            text: monitorController.isStopping ? qsTr("Stopping…")
                : monitorController.isPolling ? qsTr("Stop acquisition") : qsTr("Start acquisition")
            font.pixelSize: 14
            font.bold: true
            background: Rectangle {
                radius: 8
                color: monitorController.isStopping ? "#666"
                     : monitorController.isPolling ? Theme.btnStop : Theme.btnStart
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
                if (monitorController.isPolling)
                    monitorController.stop_polling()
                else
                    monitorController.start_polling()
            }
            Layout.alignment: Qt.AlignVCenter
        }

        BusyIndicator {
            running: monitorController.isStopping
            visible: monitorController.isStopping
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            radius: 6
            color: {
                if (!monitorController.isPolling)
                    return Theme.textSecondary
                return monitorController.statusMode === 2 ? Theme.statusErrBright : Theme.statusOk
            }
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            text: monitorController.statusText
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
            color: monitorController.errorCount > 0 ? "#3a2020" : Theme.bgSeparator
            visible: monitorController.isPolling
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: errLabel
                anchors.centerIn: parent
                text: monitorController.errorCount > 0
                    ? qsTr("Modbus read errors: %1").arg(monitorController.errorCount)
                    : qsTr("No read errors")
                color: monitorController.errorCount > 0 ? Theme.statusErr : Theme.textSecondary
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
