import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Network
import LoggerKit.Theme
import LoggerKit.Components

/**
 * Modal dialog showing provisioning QR for Central App (contains API token — LAN only).
 */
Popup {
    id: root

    property string imageBase64: ""

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(400, parent ? parent.width - 32 : 400)
    padding: AppTheme.spacingM
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
        spacing: AppTheme.spacingS

        Text {
            text: qsTr("Provisioning QR")
            font.bold: true
            font.pixelSize: AppTypography.titleLarge.pixelSize
            color: AppColors.primaryText
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
            text: qsTr("Token changed — scan QR again in Central App")
            color: AppColors.warning
            font.pixelSize: AppTypography.bodyMedium.pixelSize
            font.bold: true
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: qsTr("Scan in Central App → Add Logger → Scan QR")
            color: AppColors.accentColor
            font.pixelSize: AppTypography.bodyMedium.pixelSize
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: qsTr("Factory LAN only")
            color: AppColors.onSurfaceVariant
            font.pixelSize: AppTypography.bodyMedium.pixelSize - 1
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: qsTr("QR contains the API secret — do not share outside LAN")
            color: AppColors.error
            font.pixelSize: AppTypography.bodyMedium.pixelSize - 1
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            visible: RestApiService.state !== "listening"
            text: qsTr("REST server not listening yet — enable Active and Save first")
            color: AppColors.onSurfaceVariant
            font.pixelSize: AppTypography.bodyMedium.pixelSize - 2
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        AppButton {
            text: qsTr("Close")
            kind: AppButton.Neutral
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }

    onOpened: refresh()
}
