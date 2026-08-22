pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: root
    color: AppColors.surfaceContainerLow
    radius: AppTheme.cardRadius
    border.color: AppColors.elevatedBorder
    border.width: 1

    property alias listView: sensorListView

    signal sensorDoubleClicked()

    onVisibleChanged: {
        if (visible) {
            sensorListView.currentIndex = -1
        }
    }

    // Shared column layout for header + rows (keeps cells aligned).
    readonly property int colMarginH: 16
    readonly property int colSpacing: 8

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: AppTheme.tableHeaderHeight
            color: AppColors.surfaceContainerHigh
            topLeftRadius: AppTheme.cardRadius
            topRightRadius: AppTheme.cardRadius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.colMarginH
                anchors.rightMargin: root.colMarginH
                spacing: root.colSpacing

                Text { text: qsTr("Name");       color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 120 }
                Text { text: qsTr("Unit");       color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 50 }
                Text { text: qsTr("Slave");      color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Addr");       color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Reg");        color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Type");       color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Format");     color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Intv");       color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Thresholds"); color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                Text { text: qsTr("Active");     color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: AppColors.outline
            }
        }

        ListView {
            id: sensorListView
            clip: true
            smooth: false
            Layout.fillWidth: true; Layout.fillHeight: true
            model: SensorListModel
            boundsBehavior: Flickable.StopAtBounds
            visible: count > 0

            delegate: Rectangle {
                id: sensorRow
                required property int index
                required property string displayName
                required property string unit
                required property int slaveId
                required property int registerAddress
                required property string registerType
                required property string dataType
                required property string dataFormat
                required property var minThreshold
                required property var maxThreshold
                required property int pollInterval
                required property bool active

                width: ListView.view.width; height: 40
                // Tap-to-select highlight (no hover state — touch device).
                color: ListView.isCurrentItem
                       ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                       : "transparent"

                // Left accent bar marks the selected row clearly on touch.
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    visible: sensorRow.ListView.isCurrentItem
                    color: AppColors.primaryColor
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: AppColors.outlineVariant
                }

                // Called from nested MouseArea so that ListView.view is
                // resolved in the delegate root's context (not MouseArea's).
                function toggleSelection() {
                    var lv = ListView.view
                    if (!lv) return
                    lv.currentIndex = (lv.currentIndex === sensorRow.index) ? -1 : sensorRow.index
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: sensorRow.toggleSelection()
                    onDoubleClicked: root.sensorDoubleClicked()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.colMarginH
                    anchors.rightMargin: root.colMarginH
                    spacing: root.colSpacing
                    Text { text: sensorRow.displayName; color: AppColors.primaryText; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.weight: Font.DemiBold; Layout.preferredWidth: 120; elide: Text.ElideRight }
                    Text { text: sensorRow.unit; color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.preferredWidth: 50; elide: Text.ElideRight }
                    Text { text: sensorRow.slaveId; color: AppColors.tableCellMuted; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.family: AppTypography.monoFamily; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text { text: sensorRow.registerAddress; color: AppColors.tableCellMuted; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.family: AppTypography.monoFamily; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter }
                    Text {
                        text: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            if (t.indexOf("holding") >= 0 || t === "hr") return "HOLD"
                            if (t === "inputs" || t.indexOf("discrete") >= 0 || t === "di") return "DISC"
                            if (t.indexOf("input") >= 0 || t === "ir") return "INPT"
                            if (t.indexOf("coil") >= 0) return "COIL"
                            if (t.indexOf("invalid") >= 0) return "INV"
                            return t.substring(0, 4).toUpperCase()
                        }
                        color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : sensorRow.dataType
                        color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.preferredWidth: 65; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : sensorRow.dataFormat
                        color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        readonly property bool isBool: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            return t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                        }
                        text: isBool ? "" : (sensorRow.pollInterval + "s")
                        color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.preferredWidth: 45; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: {
                            var t = String(sensorRow.registerType).toLowerCase().trim()
                            var isBool = t.indexOf("coil") >= 0 || t.indexOf("discrete") >= 0
                            if (isBool) return ""
                            return (sensorRow.minThreshold !== undefined && sensorRow.minThreshold !== "" ? sensorRow.minThreshold : "-") + "  →  " + (sensorRow.maxThreshold !== undefined && sensorRow.maxThreshold !== "" ? sensorRow.maxThreshold : "-")
                        }
                        color: AppColors.tableCellMuted; font: AppTypography.bodyMedium; Layout.fillWidth: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        Layout.preferredWidth: 50; Layout.fillHeight: true
                        Rectangle {
                            width: 12; height: 12; radius: width / 2
                            anchors.centerIn: parent
                            color: sensorRow.active ? AppColors.success : AppColors.error
                            border.color: AppColors.outlineVariant; border.width: 1
                        }
                    }
                }
            }
        }

        EmptyStatePlaceholder {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: sensorListView.count === 0
            message: "No sensors yet.\nClick [+ Add sensor] to create one."
            iconName: "chip"
        }
    }
}
