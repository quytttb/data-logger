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
            visible: count > 0

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
                        // Analog: viền theo status và alarm
                        if (card.isAnalog) {
                            if (card.isAlarm) return AppColors.error;
                            if (card.status === "OK") return AppColors.success;
                            if (card.status === "ERR") return AppColors.error;
                            return AppColors.outlineVariant;
                        }
                        // DI/DO: viền theo ON/OFF
                        if (card.isDI && card.value === "1") return IoColors.diActive;
                        if (card.isDO && card.value === "1") return IoColors.doActive;
                        if (card.status === "ERR") return AppColors.error;
                        return AppColors.outlineVariant;
                    }
                    border.width: {
                        if (card.isAlarm) return 3;
                        if (card.status === "OK" || card.status === "ON") return 2;
                        if (card.isDI && card.value === "1") return 2;
                        if (card.isDO && card.value === "1") return 2;
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
                                font.pixelSize: AppTypography.bodyLarge.pixelSize; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: card.isAnalog
                                text: card.unit
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: AppTypography.bodyLarge.pixelSize; font.bold: true
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
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.bodyLarge.pixelSize; font.bold: true
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
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.bodyLarge.pixelSize; font.bold: true
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

                            // Status display (analog: OK/ALARM/ERR + DI states; DI/DO: keep as is)
                            Flow {
                                visible: card.isAnalog
                                Layout.fillWidth: true
                                spacing: 4

                                // Main status badge
                                Rectangle {
                                    visible: card.status !== ""
                                    color: card.status === "ALARM" ? AppColors.error
                                         : card.status === "ERR" ? AppColors.error
                                         : AppColors.success
                                    radius: AppTheme.radiusTiny
                                    implicitWidth: statusText.implicitWidth + 8
                                    implicitHeight: statusText.implicitHeight + 4
                                    Text {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: card.status
                                        color: AppColors.onPrimary
                                        font.pixelSize: AppTypography.labelSmall.pixelSize
                                        font.bold: true
                                    }
                                }

                                // DI states badges (linked DI sensors)
                                Repeater {
                                    model: card.diStates || []
                                    delegate: Rectangle {
                                        required property var modelData
                                        color: modelData.color || "#938F99"
                                        radius: AppTheme.radiusTiny
                                        implicitWidth: diStateText.implicitWidth + 8
                                        implicitHeight: diStateText.implicitHeight + 4
                                        Text {
                                            id: diStateText
                                            anchors.centerIn: parent
                                            text: modelData.label || ""
                                            color: AppColors.onPrimary
                                            font.pixelSize: AppTypography.labelSmall.pixelSize
                                            font.bold: true
                                        }
                                    }
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

        EmptyStatePlaceholder {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sensorGrid.count === 0
            message: "No active sensors.\nOpen Settings to add sensors, then press Start monitoring."
            iconName: "chip"
        }
    }
}
