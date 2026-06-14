import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Network

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
        imageBase64 = SettingsController.get_provision_qr_base64()
    }

    background: Rectangle {
        color: AppColors.surfaceContainerLow
        radius: AppTheme.cardRadius
        border.color: AppColors.elevatedBorder
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
            Layout.preferredWidth: 260
            Layout.preferredHeight: 260
            color: AppColors.surfaceContainerLow
            radius: AppTheme.listItemRadius

            Image {
                anchors.centerIn: parent
                width: 248
                height: 248
                fillMode: Image.PreserveAspectFit
                source: root.imageBase64.length > 0
                        ? ("data:image/png;base64," + root.imageBase64)
                        : ""
            }
        }

        Text {
            visible: SettingsController.provisionQrStale
            text: "Token changed — scan QR again in Central App"
            color: AppColors.warning
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
            color: AppColors.error
            font.pixelSize: Theme.fontLabelSize - 1
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: RestApiService.state !== "listening"
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
