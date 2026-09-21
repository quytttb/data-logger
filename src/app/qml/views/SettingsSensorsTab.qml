pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: root
    color: AppColors.surfaceContainerLow
    radius: AppTheme.cardRadius
    border.color: AppColors.elevatedBorder
    border.width: 1

    signal sensorDoubleClicked()

    // Selection index exposed to SettingsView (was listView.currentIndex).
    // Kept locally — TableView.currentRow is not writable.
    property int currentRow: -1

    onVisibleChanged: {
        if (visible)
            root.currentRow = -1
    }

    function _regTypeShort(t) {
        var s = String(t).toLowerCase().trim()
        if (s.indexOf("holding") >= 0 || s === "hr") return "HOLD"
        if (s === "inputs" || s.indexOf("discrete") >= 0 || s === "di") return "DISC"
        if (s.indexOf("input") >= 0 || s === "ir") return "INPT"
        if (s.indexOf("coil") >= 0) return "COIL"
        if (s.indexOf("invalid") >= 0) return "INV"
        return t.substring(0, 4).toUpperCase()
    }

    // Snapshot mirror of SensorListModel (AppTableView needs a table model).
    function rebuildRows() {
        var rows = []
        for (var i = 0; i < SensorListModel.count; ++i) {
            var s = SensorListModel.sensorAt(i)
            var regType = String(s.registerType).toLowerCase().trim()
            var isBool = regType.indexOf("coil") >= 0 || regType.indexOf("discrete") >= 0
            var thr = isBool ? "" : (
                (s.minThreshold !== undefined && s.minThreshold !== "" ? s.minThreshold : "-")
                + "  →  "
                + (s.maxThreshold !== undefined && s.maxThreshold !== "" ? s.maxThreshold : "-"))
            rows.push([
                s.displayName,
                s.unit,
                String(s.slaveId),
                String(s.registerAddress),
                root._regTypeShort(s.registerType),
                isBool ? "" : s.dataType,
                isBool ? "" : s.dataFormat,
                isBool ? "" : (s.pollInterval + "s"),
                thr,
                s.active ? "1" : "0"
            ])
        }
        sensorTableModel.setRows(rows)
    }

    Connections {
        target: SensorListModel
        function onModelReset() { root.rebuildRows() }
    }

    Component.onCompleted: root.rebuildRows()

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        AppTableView {
            id: sensorTable
            Layout.fillWidth: true; Layout.fillHeight: true
            model: sensorTableModel
            hasData: SensorListModel.count > 0
            colWeights: [0.17, 0.08, 0.07, 0.07, 0.08, 0.10, 0.09, 0.07, 0.22, 0.05]
            colMinimums: [120, 50, 45, 45, 50, 65, 55, 45, 100, 50]
            emptyMessage: qsTr("No sensors yet.\nClick [+ Add sensor] to create one.")
            emptyIconName: "chip"

            delegate: Rectangle {
                id: cell
                required property int row
                required property int column
                required property var display

                implicitHeight: 40
                color: "transparent"

                TableCellBackground { cellHovered: sensorTable.hoveredRow === cell.row }

                Rectangle {
                    anchors.fill: parent
                    color: root.currentRow === cell.row
                           ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                           : "transparent"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentRow = cell.row
                    onDoubleClicked: root.sensorDoubleClicked()
                }

                Text {
                    id: cellText
                    visible: cell.column !== 9
                    anchors {
                        left: parent.left
                        leftMargin: cell.column === 0 ? AppTheme.spacingM : AppTheme.spacingS
                        right: parent.right
                        rightMargin: AppTheme.spacingS
                        verticalCenter: parent.verticalCenter
                    }
                    text: cell.column === 9 ? "" : String(cell.display)
                    color: cell.column === 0 ? AppColors.primaryText : AppColors.tableCellMuted
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    font.family: (cell.column === 2 || cell.column === 3) ? AppTypography.monoFamily : ""
                    font.weight: cell.column === 0 ? Font.DemiBold : Font.Normal
                    horizontalAlignment: (cell.column >= 2 && cell.column <= 8) ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                // Active indicator dot (column 9).
                Rectangle {
                    visible: cell.column === 9
                    width: 12; height: 12; radius: width / 2
                    anchors.centerIn: parent
                    color: (cell.display === "1" || cell.display === true)
                           ? AppColors.success : AppColors.error
                    border.color: AppColors.outlineVariant
                    border.width: 1
                }
            }
        }
    }
}