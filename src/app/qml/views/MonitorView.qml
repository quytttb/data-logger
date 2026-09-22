pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: monitorRoot
    color: "transparent"

    // ── Local readability scale (kiosk 7" 1024×600) ──
    // Cố ý không sửa token AppTypography trong kit (submodule dùng chung
    // với central_logger) — mọi cỡ chữ phóng to nằm cục bộ ở màn này.
    readonly property int fsName: 28        // tên sensor (grid + list)
    readonly property int fsValueList: 32   // value cột list
    readonly property int fsUnit: 24        // đơn vị (grid + list)
    readonly property int fsBadge: 20       // badge status/alarm
    readonly property int fsPill: 18        // pill DI/DO
    readonly property int fsValueGrid: 42   // value analog giữa card grid
    readonly property int rowHList: 92      // chiều cao dòng list
    readonly property int cardHGrid: 180    // chiều cao card grid

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
            readonly property int outerMargin: AppTheme.spacingM
            leftMargin: outerMargin
            rightMargin: outerMargin
            topMargin: outerMargin
            bottomMargin: outerMargin

            // Responsive grid: stretch cells to fill the available width (no centering gap).
            readonly property int minCellWidth: 240
            readonly property int columns: Math.max(1, Math.floor((width - 2 * outerMargin) / minCellWidth))
            cellWidth: Math.floor((width - 2 * outerMargin) / columns)
            cellHeight: monitorRoot.cardHGrid

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
                // Guard: diStates có thể rỗng/undefined trong lúc model khởi tạo — tránh TypeError
                readonly property var topStatus: card.diStates && card.diStates.length > 0 ? card.diStates[0] : null
                readonly property bool hasStatus: topStatus !== null
                // C++ trả color dạng string ("#...") — ép qua property typed color
                // để withAlpha() đọc được .r/.g/.b (truyền string trực tiếp sẽ lỗi).
                readonly property color statusColor: card.hasStatus ? card.topStatus.color : AppColors.outlineVariant

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: AppTheme.cardRadius
                    color: AppColors.surfaceContainerLow
                    border.color: {
                        // Analog: viền theo màu DI status đang active (đã sort theo ưu tiên),
                        // hạ sáng ~35% để đỡ chói trên kiosk.
                        if (card.isAnalog) {
                            return AppColors.withAlpha(card.statusColor, 0.65);
                        }
                        // DI/DO: viền theo ON/OFF
                        if (card.isDI && card.value === "1") return AppColors.withAlpha(IoColors.diActive, 0.65);
                        if (card.isDO && card.value === "1") return AppColors.withAlpha(IoColors.doActive, 0.65);
                        return AppColors.withAlpha(AppColors.outlineVariant, 0.65);
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
                                implicitWidth: 44; implicitHeight: 26; radius: AppTheme.radiusTiny
                                color: card.isDI ? IoColors.diStrong : IoColors.doStrong
                                Text {
                                    anchors.centerIn: parent
                                    text: card.isDI ? qsTr("DI") : qsTr("DO")
                                    color: AppColors.onPrimary; font.bold: true; font.pixelSize: monitorRoot.fsPill
                                }
                            }

                            Text {
                                text: card.displayName
                                color: AppColors.primaryText
                                font.pixelSize: monitorRoot.fsName; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: card.isAnalog
                                text: card.unit
                                color: AppColors.onSurfaceVariant
                                font.pixelSize: monitorRoot.fsUnit; font.bold: true
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
                                font.pixelSize: monitorRoot.fsValueGrid
                                font.family: AppTypography.monoFamily
                                font.weight: Font.DemiBold
                            }

                            Column {
                                visible: card.isDI
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 56; implicitHeight: 56; radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? IoColors.diOnBg : IoColors.ioInactive
                                    border.color: card.value === "1" ? IoColors.diActive : IoColors.ioInactiveBorder
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? qsTr("ON") : qsTr("OFF")
                                        color: AppColors.onPrimary; font.pixelSize: 24; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? qsTr("INPUT ON") : qsTr("INPUT OFF")
                                    color: card.value === "1" ? IoColors.diActive : AppColors.onSurfaceVariant
                                    font.pixelSize: 22; font.bold: true
                                }
                            }

                            Column {
                                visible: card.isDO
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    implicitWidth: 56; implicitHeight: 56; radius: width / 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.value === "1" ? IoColors.doStrong : IoColors.ioInactive
                                    border.color: card.value === "1" ? IoColors.doActive : IoColors.ioInactiveBorder
                                    border.width: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.value === "1" ? qsTr("ON") : qsTr("OFF")
                                        color: AppColors.onPrimary; font.pixelSize: 24; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.value === "1" ? qsTr("RELAY ON") : qsTr("RELAY OFF")
                                    color: card.value === "1" ? IoColors.doActive : AppColors.onSurfaceVariant
                                    font.pixelSize: 22; font.bold: true
                                }
                            }
                        }

                        // ── Footer Row ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Status badge: nền mờ dịu, không viền (giống style list) —
                            // badge DO trigger (MAX/MIN) giữ nguyên bên dưới.
                            Rectangle {
                                visible: card.isAnalog && card.hasStatus
                                color: card.hasStatus ? AppColors.withAlpha(card.topStatus.color, 0.12) : "transparent"
                                border.width: 0
                                radius: AppTheme.radiusTiny
                                implicitWidth: statusText.implicitWidth + 10
                                implicitHeight: statusText.implicitHeight + 4
                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: card.hasStatus ? card.topStatus.label : ""
                                    color: card.hasStatus ? card.topStatus.color : "transparent"
                                    font.pixelSize: monitorRoot.fsBadge
                                    font.bold: true
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // MAX/MIN alarm badge — màu khớp dạng List: nền error trong suốt + text error
                            Rectangle {
                                visible: card.isAlarm && card.isAnalog
                                color: AppColors.withAlpha(AppColors.error, 0.2)
                                border.width: 1
                                border.color: AppColors.error
                                radius: AppTheme.radiusTiny
                                implicitWidth: alarmLabel.implicitWidth + 10
                                implicitHeight: alarmLabel.implicitHeight + 4
                                Text {
                                    id: alarmLabel
                                    anchors.centerIn: parent
                                    text: card.alarmType === "min" ? qsTr("▼ MIN")
                                        : (card.alarmType === "max" ? qsTr("▲ MAX") : qsTr("ALARM"))
                                    color: AppColors.error
                                    font.pixelSize: monitorRoot.fsBadge; font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bridge MonitorModel (list) sang TableView: cùng AppTableView + colWidths
        // với Sensors/Attach/History nên header/cell luôn thẳng hàng.
        MonitorTableModel {
            id: monitorTableModel
            sourceModel: MonitorModel
            showDigitalIO: SettingsController.monitorShowDigitalIO
        }

        AppTableView {
            id: monitorTable
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: SettingsController.monitorViewMode === "list"
            model: monitorTableModel
            hasData: monitorTableModel.count > 0
            colWeights: [0.35, 0.26, 0.15, 0.24]
            colMinimums: [120, 70, 50, 160]
            headerAlignRight: function(col) { return col === 1 }
            headerAlignCenter: function(col) { return col === 2 || col === 3 }
            emptyMessage: qsTr("No active sensors.\nOpen Settings to add sensors, then press Start monitoring.")
            emptyIconName: "chip"

            delegate: Rectangle {
                id: monCell
                required property int row
                required property int column
                required property string displayName
                required property string value
                required property string unit
                required property string sensorType
                required property bool isAlarm
                required property string alarmType
                required property var diStates

                readonly property bool isAnalog: monCell.sensorType === "ANALOG"
                readonly property bool isDI: monCell.sensorType === "DI"
                readonly property bool isDO: monCell.sensorType === "DO"
                readonly property bool isOn: monCell.value === "1"
                // Guard: diStates có thể rỗng/undefined lúc model khởi tạo
                readonly property var topStatus: monCell.diStates && monCell.diStates.length > 0 ? monCell.diStates[0] : null
                readonly property bool hasStatus: monCell.topStatus !== null
                readonly property color stateColor: {
                    if (monCell.isAnalog && monCell.hasStatus)
                        return monCell.topStatus.color
                    if (monCell.isDI && monCell.isOn)
                        return IoColors.diActive
                    if (monCell.isDO && monCell.isOn)
                        return IoColors.doActive
                    return AppColors.outlineVariant
                }

                implicitHeight: monitorRoot.rowHList
                color: "transparent"

                TableCellBackground { cellHovered: false }

                // ── Cột Sensor: pill DI/DO + tên ──
                Row {
                    visible: monCell.column === 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        visible: !monCell.isAnalog
                        width: 40; height: 26; radius: AppTheme.radiusTiny
                        anchors.verticalCenter: parent.verticalCenter
                        color: monCell.isDI ? IoColors.diStrong : IoColors.doStrong
                        Label {
                            anchors.centerIn: parent
                            text: monCell.isDI ? qsTr("DI") : qsTr("DO")
                            color: AppColors.onPrimary
                            font.bold: true
                            font.pixelSize: monitorRoot.fsPill
                        }
                    }
                    Label {
                        width: parent.width - (monCell.isAnalog ? 0 : 48) - 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: monCell.displayName
                        color: AppColors.primaryText
                        font.family: AppTypography.titleSmall.family
                        font.pixelSize: monitorRoot.fsName
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                // ── Cột Value ──
                Label {
                    visible: monCell.column === 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: monCell.isAnalog ? monCell.value : (monCell.isOn ? qsTr("ON") : qsTr("OFF"))
                    color: monCell.isAlarm ? AppColors.error : AppColors.primaryText
                    font.family: monCell.isAnalog ? AppTypography.monoFamily : AppTypography.titleSmall.family
                    font.pixelSize: monitorRoot.fsValueList
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                // ── Cột Unit ──
                Label {
                    visible: monCell.column === 2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: monCell.isAnalog ? monCell.unit : ""
                    color: AppColors.onSurfaceVariant
                    font.pixelSize: monitorRoot.fsUnit
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                // ── Cột Status: 2 badge co theo text (trạng thái + trigger/alarm) ──
                Row {
                    visible: monCell.column === 3
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        implicitWidth: Math.min(statusLabel.implicitWidth + 16, 150)
                        implicitHeight: 36
                        radius: AppTheme.radiusTiny
                        color: monCell.isAlarm ? AppColors.error : AppColors.withAlpha(monCell.stateColor, 0.2)
                        Label {
                            id: statusLabel
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: (monCell.isAnalog && monCell.hasStatus) ? monCell.topStatus.label
                                : ((monCell.isDI || monCell.isDO) ? (monCell.isOn ? qsTr("Active") : qsTr("Inactive")) : qsTr("No status"))
                            color: monCell.isAlarm ? AppColors.onPrimary : monCell.stateColor
                            font.pixelSize: monitorRoot.fsBadge
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        visible: monCell.isAnalog && monCell.isAlarm
                        implicitWidth: Math.min(triggerLabel.implicitWidth + 16, 150)
                        implicitHeight: 36
                        radius: AppTheme.radiusTiny
                        color: AppColors.error
                        Label {
                            id: triggerLabel
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: monCell.alarmType === "min" ? qsTr("MIN alarm") : qsTr("MAX alarm")
                            color: AppColors.onPrimary
                            font.pixelSize: monitorRoot.fsBadge
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
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
