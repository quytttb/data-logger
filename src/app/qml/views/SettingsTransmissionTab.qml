pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    property bool configChanged: false

    // sensorId lives in a side array (it is cofig state, not a display column).
    property var txIds: []

    JsonTableModel { id: txTable }

    function reloadRows() {
        txIds = []
        var rows = SensorListModel.transmissionRows()
        var cells = []
        for (var i = 0; i < rows.length; ++i) {
            var r = rows[i]
            txIds.push(r.sensorId)
            cells.push([String(r.stt), r.name, r.sensorSymbol || "", r.transmitEnabled === true])
        }
        txTable.setHeaders(["No.", "Sensor name", "Sensor symbol", "Transmit"])
        txTable.setRows(cells)
    }

    function buildSavePayload() {
        var out = []
        for (var i = 0; i < txTable.count; ++i) {
            out.push({
                sensorId: txIds[i],
                sensorSymbol: txTable.cell(i, 2),
                transmitEnabled: txTable.cell(i, 3) === true
            })
        }
        return out
    }

    // Persisted by the shared Save button on the task bar
    // (SettingsView.saveConfig calls this before SettingsController.saveConfig).
    function saveRows() {
        SensorListModel.applyTransmission(buildSavePayload())
    }

    // Rows checked for bulk-disable (Delete button).
    function buildDisablePayload() {
        var out = []
        for (var i = 0; i < txTable.count; ++i) {
            if (txTable.cell(i, 3) !== true)
                continue
            out.push({
                sensorId: txIds[i],
                sensorSymbol: txTable.cell(i, 2),
                transmitEnabled: false
            })
        }
        return out
    }

    Component.onCompleted: reloadRows()

    Connections {
        target: SensorListModel
        function onModelReset() { root.reloadRows() }
    }

    Connections {
        target: SettingsController
        function onConfigLoaded() {
            autoAddSwitch.checked = SettingsController.autoAddTransmit
        }
    }

    ElevatedPane {
        anchors.fill: parent
        padding: 20
        contentSpacing: AppTheme.spacingM

        Text {
            text: qsTr("Transfer Parameters")
            color: AppColors.accentColor
            font.bold: true
            font.pixelSize: AppTypography.titleSmall.pixelSize
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: AppTheme.spacingM

            Text {
                text: qsTr("Auto-add new sensors")
                color: AppColors.onSurfaceVariant
                font.pixelSize: AppTypography.bodyMedium.pixelSize
            }
            Switch {
                id: autoAddSwitch
                checked: SettingsController ? SettingsController.autoAddTransmit : true
                onToggled: {
                    SettingsController.autoAddTransmit = checked
                    root.configChanged = true
                }
            }
            Item { Layout.fillWidth: true }

            AppButton {
                text: qsTr("Select all")
                kind: AppButton.Neutral
                onClicked: {
                    for (var i = 0; i < txTable.count; ++i)
                        txTable.setCell(i, 3, true)
                    root.configChanged = true
                }
            }
            AppButton {
                text: qsTr("Deselect all")
                kind: AppButton.Neutral
                onClicked: {
                    for (var i = 0; i < txTable.count; ++i)
                        txTable.setCell(i, 3, false)
                    root.configChanged = true
                }
            }
        }

        AppTableView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: txTable
            colWeights: [0.08, 0.36, 0.46, 0.10]
            colMinimums: [36, 140, 120, 56]
            // Editable cells carry ComboBox/CheckBox state — a fresh delegate
            // per change keeps control state in sync with the model.
            reuseItems: false
            emptyMessage: qsTr("No analog sensors to transfer yet.")

            delegate: Item {
                id: cell
                required property int row
                required property int column
                required property var display

                implicitHeight: 44

                Text {
                    visible: cell.column !== 2 && cell.column !== 3
                    anchors {
                        left: parent.left
                        leftMargin: cell.column === 0 ? AppTheme.spacingM : AppTheme.spacingS
                        right: parent.right
                        rightMargin: AppTheme.spacingS
                        verticalCenter: parent.verticalCenter
                    }
                    text: String(cell.display)
                    color: cell.column === 0 ? AppColors.onSurfaceVariant : AppColors.primaryText
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    font.weight: cell.column === 1 ? Font.DemiBold : Font.Normal
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Item {
                    visible: cell.column === 3
                    anchors.fill: parent
                    CheckBox {
                        anchors.centerIn: parent
                        checked: cell.display === true
                        onToggled: {
                            txTable.setCell(cell.row, 3, checked)
                            root.configChanged = true
                        }
                    }
                }

                ComboBox {
                    id: symCombo
                    visible: cell.column === 2
                    anchors.fill: parent
                    // Dropdown-only. A legacy custom symbol that is missing from
                    // the TT10 catalog is pushed into the model so it stays visible.
                    model: SensorSymbols.symbols
                    Component.onCompleted: {
                        let v = String(cell.display)
                        let idx = find(v)
                        if (idx < 0) {
                            let list = SensorSymbols.symbols.slice(0)
                            list.push(v)
                            symCombo.model = list
                            idx = symCombo.count - 1
                        }
                        currentIndex = idx >= 0 ? idx : -1
                    }
                    onActivated: {
                        txTable.setCell(cell.row, 2, currentText)
                        root.configChanged = true
                    }
                }
            }
        }

        // Row saving goes through the shared Save button on the task bar
        // (SettingsView.saveConfig calls saveRows()). Only row deletion
        // stays local — there is no task-bar equivalent for it.
        RowLayout {
            Layout.fillWidth: true
            spacing: AppTheme.spacingM
            Item { Layout.fillWidth: true }

            AppButton {
                text: qsTr("Delete")
                fillColor: AppColors.error
                onClicked: {
                    var rows = root.buildDisablePayload()
                    if (rows.length === 0)
                        return
                    SensorListModel.applyTransmission(rows)
                    root.configChanged = false
                }
            }
        }
    }
}