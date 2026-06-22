import QtQuick

import DataLogger.Theme

Rectangle {
    required property bool cellHovered

    anchors.fill: parent
    color: cellHovered ? AppColors.withAlpha(AppColors.primaryText, 0.08) : "transparent"

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: AppColors.outlineVariant
    }
}
