pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: monitorRoot
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        spacing: AppTheme.spacingSM

        // ── Sensor Cards Grid (centered) ─────────────────────────────
        GridView {
            id: sensorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: MonitorModel
            visible: count > 0 && SettingsController.monitorViewMode === "grid"

            // Padding lives on the scroll content (Flickable margins): it only
            // appears before the first row / after the last row, and scrolls with
            // the content — no rigid dead-band around the viewport.
            readonly property int outerMargin: 15
            leftMargin: outerMargin
            rightMargin: outerMargin
            topMargin: outerMargin
            bottomMargin: outerMargin

            // Responsive grid: stretch cells to fill the available width (no centering gap).
            readonly property int minCellWidth: 240
            readonly property int columns: Math.max(1, Math.floor((width - 2 * outerMargin) / minCellWidth))
            cellWidth: Math.floor((width - 2 * outerMargin) / columns)
            cellHeight: 150

            delegate: Item {
                id: card
                implicitWidth: sensorGrid.cellWidth
                implicitHeight: sensorGrid.cellHeight

                // Hide DI/DO if monitorShowDigitalIO is false
                visible: {
                    if (card.sensorType === "DI" || card.sensorType === "DO") {
                        return SettingsController.monitorShowDigitalIO
                    }
                    return true
                }

                required property string name
                required property string status
                required property string value
                required property string rawValue
                required property string unit
                required property string lastUpdate
                required property bool   isAlarm
                required property string alarmType
                required property string sensorType
                required property string displayName
                required property var    diStates  // QVariantList of {label, color}

                readonly property bool isAnalog: card.sensorType === "ANALOG"
                readonly property bool isDI: card.sensorType === "DI"
                readonly property bool isDO: card.sensorType === "DO"

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: AppTheme.cardRadius
                    color: AppColors.surfaceContainerLow
                    border.color: {
                        // Analog: viền theo màu DI status đang active (đã sort theo ưu tiên)
                        if (card.isAnalog) {
                            if (card.diStates && card.diStates.length > 0) {
                                return card.diStates[0].color;
                            }
                            return AppColors.outlineVariant; // không có DI active
                        }
                        // DI/DO: viền theo ON/OFF
                        if (card.isDI && card.value === "1") return IoColors.diActive;
                        if (card.isDO && card.value === "1") return IoColors.doActive;
                        return AppColors.outlineVariant;
                    }
                    border.width: {
                        // Analog: Error/Maintenance dày hơn (3), còn lại 2
                        if (card.isAnalog && card.diStates && card.diStates.length > 0) {
                            var label = card.diStates[0].label;
                            if (label === "Error" || label === "Maintenance") return 3;
                            return 2;
                        }
                        // DI/DO: ON dày hơn
                        if ((card.isDI || card.isDO) && card.value === "1") return 2;
                        return 1;
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: AppTheme.spacingSM
                        spacing: 4

                        // ── Header Row ──────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                visible: !card.isAnalog
                                implicitWidth: 36; implicitHeight: 18; radius: AppTheme.radiusTiny
                                color: card.isDI ? IoColors.diStrong : IoColors.doStrong
                                Text {
                                    anchors.centerIn: parent
                                    text: card.isDI ? qsTr("DI") : qsTr("DO")
                                    color: AppColors.onPrimary; font.bold: true; font.pixelSize: AppTypography.labelSmall.pixelSize
                                }
                            }

                            Text {
                                text: card.displayName
                                color: AppColors.accentColor
                                font.pixelSize: AppTypography.titleSmall.pixelSize; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: card.isAnalog
                                text: card.unit
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: AppTypography.titleSmall.pixelSize; font.bold: true
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.NoWrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }

                        // ── Center Content ───────────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                visible: card.isAnalog
                                anchors.centerIn: parent
                                text: card.value
                                color: card.isAlarm ? AppColors.error
                                     : (card.status === "ERR" ? AppColors.error : AppColors.primaryText)
                                font.pixelSize: card.value === "---" ? 32 : 42
                                font.family: AppTypography.monoFamily
                                font.bold: true
                            }

                            Column {
                                visible: card.isDI
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 48; radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? IoColors.diOnBg : IoColors.ioInactive
                                    border.color: card.value === "1" ? IoColors.diActive : IoColors.ioInactiveBorder
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? qsTr("ON") : qsTr("OFF")
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.titleSmall.pixelSize; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? qsTr("INPUT ON") : qsTr("INPUT OFF")
                                    color: card.value === "1" ? IoColors.diActive : AppColors.onSurfaceVariant
                                    font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true
                                }
                            }

                            Column {
                                visible: card.isDO
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 48; radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? IoColors.doStrong : IoColors.ioInactive
                                    border.color: card.value === "1" ? IoColors.doActive : IoColors.ioInactiveBorder
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? qsTr("ON") : qsTr("OFF")
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.titleSmall.pixelSize; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? qsTr("RELAY ON") : qsTr("RELAY OFF")
                                    color: card.value === "1" ? IoColors.doActive : AppColors.onSurfaceVariant
                                    font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true
                                }
                            }
                        }

                        // ── Footer Row ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Status badge: hiển thị trạng thái DI ưu tiên cao nhất (đã sort trong C++)
                            Rectangle {
                                visible: card.isAnalog && card.diStates && card.diStates.length > 0
                                color: card.diStates && card.diStates.length > 0 ? card.diStates[0].color : "#938F99"
                                radius: AppTheme.radiusTiny
                                implicitWidth: statusText.implicitWidth + 8
                                implicitHeight: statusText.implicitHeight + 4
                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: card.diStates && card.diStates.length > 0 ? card.diStates[0].label : ""
                                    color: AppColors.onPrimary
                                    font.pixelSize: AppTypography.labelSmall.pixelSize
                                    font.bold: true
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // MAX/MIN alarm badge (moved from header)
                            Rectangle {
                                visible: card.isAlarm && card.isAnalog
                                color: AppColors.error
                                radius: AppTheme.radiusTiny
                                implicitWidth: alarmLabel.implicitWidth + 8
                                implicitHeight: alarmLabel.implicitHeight + 4
                                Text {
                                    id: alarmLabel
                                    anchors.centerIn: parent
                                    text: card.alarmType === "min" ? qsTr("▼ MIN")
                                        : (card.alarmType === "max" ? qsTr("▲ MAX") : qsTr("ALARM"))
                                    color: AppColors.onPrimary
                                    font.pixelSize: AppTypography.labelSmall.pixelSize; font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: sensorList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: MonitorModel
            visible: count > 0 && SettingsController.monitorViewMode === "list"
            spacing: AppTheme.spacingS
            leftMargin: 15
            rightMargin: 15
            topMargin: 15
            bottomMargin: 15

            header: Rectangle {
                width: sensorList.width - sensorList.leftMargin - sensorList.rightMargin
                height: 40
                radius: AppTheme.listItemRadius
                color: AppColors.surfaceContainerHigh
                border.color: AppColors.outlineVariant
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: AppTheme.spacingM
                    anchors.rightMargin: AppTheme.spacingM
                    spacing: AppTheme.spacingM

                    Label { text: qsTr("Sensor"); font.bold: true; color: AppColors.onSurfaceVariant; Layout.preferredWidth: parent.width * 0.30 }
                    Label { text: qsTr("Value"); font.bold: true; color: AppColors.onSurfaceVariant; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: parent.width * 0.20 }
                    Label { text: qsTr("Unit"); font.bold: true; color: AppColors.onSurfaceVariant; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: parent.width * 0.10 }
                    Label { text: qsTr("Status"); font.bold: true; color: AppColors.onSurfaceVariant; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: parent.width * 0.20 }
                    Label { text: qsTr("Updated"); font.bold: true; color: AppColors.onSurfaceVariant; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: parent.width * 0.20 }
                }
            }

            delegate: Rectangle {
                id: sensorRow
                required property string value
                required property string unit
                required property string lastUpdate
                required property bool isAlarm
                required property string alarmType
                required property string sensorType
                required property string displayName
                required property var diStates

                readonly property bool isAnalog: sensorType === "ANALOG"
                readonly property bool isDI: sensorType === "DI"
                readonly property bool isDO: sensorType === "DO"
                readonly property bool isOn: value === "1"
                readonly property color stateColor: {
                    if (isAnalog && diStates && diStates.length > 0)
                        return diStates[0].color
                    if (isDI && isOn)
                        return IoColors.diActive
                    if (isDO && isOn)
                        return IoColors.doActive
                    return AppColors.outlineVariant
                }

                width: sensorList.width - sensorList.leftMargin - sensorList.rightMargin
                height: visible ? 64 : 0
                visible: isAnalog || SettingsController.monitorShowDigitalIO
                radius: AppTheme.listItemRadius
                color: AppColors.surfaceContainerLow
                border.color: stateColor
                border.width: (isAlarm || (isAnalog && diStates && diStates.length > 0) || ((isDI || isDO) && isOn)) ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: AppTheme.spacingM
                    anchors.rightMargin: AppTheme.spacingM
                    spacing: AppTheme.spacingM

                    RowLayout {
                        Layout.preferredWidth: parent.width * 0.30
                        spacing: AppTheme.spacingS

                        Rectangle {
                            visible: !sensorRow.isAnalog
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 20
                            radius: AppTheme.radiusTiny
                            color: sensorRow.isDI ? IoColors.diStrong : IoColors.doStrong
                            Label {
                                anchors.centerIn: parent
                                text: sensorRow.isDI ? qsTr("DI") : qsTr("DO")
                                color: AppColors.onPrimary
                                font.bold: true
                            }
                        }
                        Label {
                            text: sensorRow.displayName
                            color: AppColors.accentColor
                            font: AppTypography.titleSmall
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Label {
                        text: sensorRow.isAnalog ? sensorRow.value : (sensorRow.isOn ? qsTr("ON") : qsTr("OFF"))
                        color: sensorRow.isAlarm ? AppColors.error : AppColors.primaryText
                        font.family: sensorRow.isAnalog ? AppTypography.monoFamily : AppTypography.titleSmall.family
                        font.pixelSize: AppTypography.titleMedium.pixelSize
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: parent.width * 0.20
                    }
                    Label {
                        text: sensorRow.isAnalog ? sensorRow.unit : ""
                        color: AppColors.onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        Layout.preferredWidth: parent.width * 0.10
                    }
                    Rectangle {
                        readonly property string label: sensorRow.isAnalog && sensorRow.diStates && sensorRow.diStates.length > 0
                            ? sensorRow.diStates[0].label
                            : (sensorRow.isAnalog && sensorRow.isAlarm
                               ? (sensorRow.alarmType === "min" ? qsTr("MIN alarm") : qsTr("MAX alarm"))
                               : (sensorRow.isDI || sensorRow.isDO ? (sensorRow.isOn ? qsTr("Active") : qsTr("Inactive")) : qsTr("No status")))
                        Layout.preferredWidth: parent.width * 0.20
                        Layout.preferredHeight: 28
                        radius: AppTheme.radiusTiny
                        color: sensorRow.isAlarm ? AppColors.error : AppColors.withAlpha(sensorRow.stateColor, 0.2)
                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: parent.label
                            color: sensorRow.isAlarm ? AppColors.onPrimary : sensorRow.stateColor
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    Label {
                        text: sensorRow.lastUpdate
                        color: AppColors.onSurfaceVariant
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        Layout.preferredWidth: parent.width * 0.20
                    }
                }
            }
        }

        EmptyStatePlaceholder {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sensorGrid.count === 0
            message: "No active sensors.\nOpen Settings to add sensors, then press Start monitoring."
            iconName: "chip"
        }
    }
}
