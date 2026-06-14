import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Theme

Popup {
    id: root

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent.width - 32)
    padding: 20
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string detailTitle: ""
    property string detailBody: ""

    Connections {
        target: AppNotifier
        function onDetailRequested(title, body) {
            root.detailTitle = title
            root.detailBody = body
            root.open()
        }
    }

    background: Rectangle {
        color: AppColors.surfaceContainerLow
        radius: AppTheme.cardRadius
        border.color: AppColors.elevatedBorder
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 12

        Label {
            text: root.detailTitle
            font: AppTypography.titleMedium
            color: AppColors.primaryText
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Label {
            text: root.detailBody
            font: AppTypography.bodyMedium
            color: AppColors.textSubtle
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Button {
            text: qsTr("Close")
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }
}
