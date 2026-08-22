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
                        if (card.isAlarm) return AppColors.error;
                        if (card.status === "OK" || card.status === "ON") return AppColors.success;
                        if (card.status === "ERR") return AppColors.error;
                        if (card.isDI && card.value === "1") return IoColors.diActive;
                        return AppColors.outlineVariant;
                    }
                    border.width: {
                        if (card.isAlarm) return 3;
                        if (card.status === "OK" || card.status === "ON") return 2;
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
                                    text: card.isDI ? "DI" : "DO"
                                    color: AppColors.onPrimary; font.bold: true; font.pixelSize: AppTypography.labelTiny.pixelSize
                                }
                            }

                            Text {
                                text: card.displayName
                                color: AppColors.accentColor
                                font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: card.isAlarm && card.isAnalog
                                color: AppColors.error
                                radius: AppTheme.radiusTiny
                                implicitWidth: alarmLabel.implicitWidth + 8
                                implicitHeight: alarmLabel.implicitHeight + 4
                                Text {
                                    id: alarmLabel
                                    anchors.centerIn: parent
                                    text: card.alarmType === "min" ? "▼ MIN"
                                        : (card.alarmType === "max" ? "▲ MAX" : "ALARM")
                                    color: AppColors.onPrimary
                                    font.pixelSize: AppTypography.labelTiny.pixelSize; font.bold: true
                                }
                            }

                            Text {
                                visible: card.isAnalog
                                text: card.unit
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
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
                                font.pixelSize: card.value === "---" ? 28 : 36
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
                                        text: card.value === "1" ? "ON" : "OFF"
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? "INPUT ON" : "INPUT OFF"
                                    color: card.value === "1" ? IoColors.diActive : AppColors.onSurfaceVariant
                                    font.pixelSize: AppTypography.labelSmall.pixelSize; font.bold: true
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
                                        text: card.value === "1" ? "ON" : "OFF"
                                        color: AppColors.onPrimary; font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? "RELAY ON" : "RELAY OFF"
                                    color: card.value === "1" ? IoColors.doActive : AppColors.onSurfaceVariant
                                    font.pixelSize: AppTypography.labelSmall.pixelSize; font.bold: true
                                }
                            }
                        }

                        // ── Footer Row ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                visible: card.isAnalog
                                text: (card.rawValue !== "" && card.rawValue !== "---") ? "RAW " + card.rawValue : ""
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: AppTypography.labelTiny.pixelSize; font.family: AppTypography.monoFamily
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: card.lastUpdate || ""
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: AppTypography.labelSmall.pixelSize
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
