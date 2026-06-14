import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Theme

Pane {
    id: root

    property int contentSpacing: 0

    Material.theme: AppTheme.materialTheme
    Material.elevation: 0
    padding: AppTheme.sectionSpacing

    implicitWidth: 0
    implicitHeight: 0

    default property alias content: contentColumn.data

    background: Rectangle {
        color: AppColors.surfaceContainerLow
        radius: AppTheme.cardRadius
        border.width: 1
        border.color: AppColors.elevatedBorder
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: root.contentSpacing
    }
}
