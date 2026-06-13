import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

/**
 * Modal dialog showing provisioning QR for Central App (contains API token — LAN only).
 */
Popup {
    id: root

    property string imageBase64: ""

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(400, parent ? parent.width - 32 : 400)
    padding: 18
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function refresh() {
        imageBase64 = settingsController.get_provision_qr_base64()
    }

    background: Rectangle {
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: Theme.accent
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            text: "Provisioning QR"
            font.bold: true
            font.pixelSize: 17
            color: Theme.textPrimary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 260
            height: 260
            color: "#ffffff"
            radius: Theme.radiusSmall

            Image {
                anchors.centerIn: parent
                width: 248
                height: 248
                fillMode: Image.PreserveAspectFit
                source: imageBase64.length > 0
                        ? ("data:image/png;base64," + imageBase64)
                        : ""
            }
        }

        Text {
            visible: settingsController.provisionQrStale
            text: "Token changed — scan QR again in Central App"
            color: "#d4a62d"
            font.pixelSize: Theme.fontLabelSize
            font.bold: true
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "Scan in Central App → Add Logger → Scan QR"
            color: Theme.accentText
            font.pixelSize: Theme.fontLabelSize
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "Factory LAN only"
            color: Theme.textLabel
            font.pixelSize: Theme.fontLabelSize - 1
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "QR contains the API secret — do not share outside LAN"
            color: "#ff8080"
            font.pixelSize: Theme.fontLabelSize - 1
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: restApiService.state !== "listening"
            text: "REST server not listening yet — enable Active and Save first"
            color: Theme.textLabel
            font.pixelSize: Theme.fontLabelSize - 2
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Button {
            text: "Close"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }

    onOpened: refresh()
}
