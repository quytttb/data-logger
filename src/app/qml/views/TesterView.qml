pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: testerRoot
    anchors.fill: parent

    property bool narrow: width < 700
    property bool hideZeros: false
    readonly property TesterOperationsTab opsItem: opsTab

    signal navigateToAddSensor(var data)
    function showError(title, msg) {
        AppNotifier.show(msg || title, "error", { detailTitle: title, detailText: msg })
    }

    function showToast(title, msg) {
        AppNotifier.show(msg || title, "success")
    }

    MessagePopup {
        id: errorDialog
    }

    function openSaveSensorInSettings() {
        var o = opsTab

        var data = {
            slaveId: o.slaveSpin.value,
            registerAddress: o.scanStartSpin.value,
            registerType: o.regTypeCombo.currentText,
            dataType: o.dataTypeCombo.currentText,
            dataFormat: o.dataFormatCombo.currentText
        }

        navigateToAddSensor(data)
    }

    function connectOrDisconnect() {
        if (TesterController.isConnected) {
            // Disconnect: TesterController hands the serial port back to
            // monitoring if the tester had paused it.
            TesterController.disconnectSerial()
        } else {
            // Connect: pause monitoring first (if running or retrying), then
            // connect once it is fully idle — handled inside TesterController.
            TesterController.connectWithMonitorPause(
                MonitorController,
                SettingsController.serialPort,
                SettingsController.serialBaudrate,
                SettingsController.serialBytesize,
                SettingsController.serialParity,
                SettingsController.serialStopbits
            )
        }
    }

    function performScan() {
        if (!TesterController.isConnected) {
            showError("Error", "Not connected to Modbus. Check Connection settings.")
            return
        }
        var o = opsTab
        if (o.scanStartSpin.value > o.scanEndSpin.value) {
            showError("Error", "Start address must be ≤ end address.")
            return
        }
        scanModel.clear()
        TesterController.scanSlaves(
            o.scanStartSpin.value, o.scanEndSpin.value, o.scanCountSpin.value,
            o.regTypeCombo.currentText, o.dataTypeCombo.currentText,
            o.slaveSpin.value, o.dataFormatCombo.currentText
        )
    }

    property int _pendingWriteAddr: -1
    property string _pendingWriteVal: ""

    function performWrite() {
        if (!TesterController.isConnected) {
            showError("Error", "Not connected to Modbus.")
            return
        }
        var o = opsTab
        var addr = o.writeAddrSpin.value
        var valStr = String(o.writeValSpin.value)
        var regType = o.regTypeCombo.currentText
        var dataType = o.isBooleanType ? "uint16" : o.dataTypeCombo.currentText
        var slaveId = o.slaveSpin.value
        testerRoot._pendingWriteAddr = addr
        testerRoot._pendingWriteVal  = valStr
        TesterController.write_single(regType, addr, valStr, slaveId, dataType)
    }

    function clearResultsTable() { scanModel.clear(); resultTable.clear() }

    function toggleScan() {
        if (TesterController.isScanning)
            TesterController.stopScan()
        else
            performScan()
    }

    Connections {
        target: TesterController
        function onMessageSent(title, msg) {
            var isError = title.toLowerCase() === "error"
            if (isError) testerRoot.showError(title, msg)
            else testerRoot.showToast(title, msg)
        }
        function onScanResultReceived(addr, val) {
            scanModel.append({ "address": addr, "value": val })
            if (!testerRoot.hideZeros || !testerRoot._isZeroValue(val))
                testerRoot._appendResultRow(addr, val)
        }
        function onWriteResult(result) {
            if (result.ok) {
                let addr = testerRoot._pendingWriteAddr
                let valStr = testerRoot._pendingWriteVal
                testerRoot.showToast("Write OK", "Wrote " + valStr + " to address " + addr)
                let found = false
                for (let i = 0; i < scanModel.count; i++) {
                    if (scanModel.get(i).address === addr) {
                        scanModel.setProperty(i, "value", valStr)
                        found = true
                        break
                    }
                }
                if (!found) scanModel.append({ "address": addr, "value": valStr })
                testerRoot._rebuildFiltered()
            } else {
                testerRoot.showError("Write Error", result.error || "Write failed")
            }
        }
    }

    // Full result history (hidden source; feeds resultTable which applies
    // the hideZeros filter). Kept separate from the visible table so toggling
    // hideZeros can rebuild without losing un-filtered rows.
    ListModel { id: scanModel }

    JsonTableModel {
        id: resultTable
        Component.onCompleted: setHeaders(["Address", "Value"])
    }

    // Mirrors the visible-filtered table incrementally (no full reset, so
    // TableView scroll position stays put while a scan streams in).
    function _appendResultRow(addr, val) {
        let idx = resultTable.findRow(0, addr)
        if (idx >= 0) resultTable.setCell(idx, 1, val)
        else resultTable.appendRow([addr, val])
    }

    function _rebuildFiltered() {
        let rows = []
        for (let i = 0; i < scanModel.count; i++) {
            let item = scanModel.get(i)
            if (testerRoot.hideZeros && testerRoot._isZeroValue(item.value))
                continue
            rows.push([item.address, item.value])
        }
        resultTable.setRows(rows)
    }

    function _isZeroValue(val) {
        let s = String(val).trim()
        if (s === "0" || s === "0.0" || s === "0.00" || s === "0.000" || s === "0.0000") return true
        let m = s.match(/^\[([\d,\s]*)\]$/)
        if (m) {
            let nums = m[1].split(",")
            for (let i = 0; i < nums.length; i++) {
                if (parseInt(nums[i].trim()) !== 0) return false
            }
            return true
        }
        return false
    }

    onHideZerosChanged: _rebuildFiltered()

    GridLayout {
        id: split
        anchors.fill: parent
        columns: testerRoot.narrow ? 1 : 3
        rowSpacing: 0
        columnSpacing: 0

        ScrollView {
            id: leftScroll; clip: true; padding: 24
            Layout.minimumWidth: testerRoot.narrow ? 0 : 260
            Layout.preferredWidth: testerRoot.narrow ? -1 : Math.round((split.width - 1) * 0.4)
            Layout.preferredHeight: testerRoot.narrow ? 380 : -1
            Layout.fillWidth: testerRoot.narrow
            Layout.fillHeight: !testerRoot.narrow

            ColumnLayout {
                width: leftScroll.availableWidth; spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: infoBanner.implicitHeight + 16
                    color: AppColors.surfaceContainerHigh; radius: AppTheme.radiusTiny
                    border.color: AppColors.outlineVariant; border.width: 1

                    ColumnLayout {
                        id: infoBanner
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text {
                            text: qsTr("Serial: ") + SettingsController.serialPort + " @ " + SettingsController.serialBaudrate + " baud"
                            color: AppColors.primaryText; font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
                        }
                        Text {
                            text: SettingsController.serialBytesize + qsTr("bit, Parity:") + SettingsController.serialParity + qsTr(", Stop:") + SettingsController.serialStopbits
                            color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.labelMedium.pixelSize
                        }
                    }
                }

                TesterOperationsTab {
                    id: opsTab
                    Layout.fillWidth: true
                }
            }
        }

        // Fixed divider (non-draggable)
        Rectangle {
            color: AppColors.outlineVariant
            Layout.fillWidth: testerRoot.narrow
            Layout.fillHeight: !testerRoot.narrow
            Layout.preferredWidth: testerRoot.narrow ? -1 : 1
            Layout.preferredHeight: testerRoot.narrow ? 1 : -1
        }

        Pane {
            Layout.fillWidth: true; Layout.fillHeight: true; padding: AppTheme.spacingS
            background: null

            ColumnLayout {
                anchors.fill: parent; spacing: 8

                Label { text: qsTr("Scan results"); font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true; color: AppColors.accentColor; Layout.fillWidth: true }

                ElevatedPane {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    padding: 0
                    contentSpacing: 0

                    AppTableView {
                        id: resultsTable
                        Layout.fillWidth: true; Layout.fillHeight: true
                        model: resultTable
                        colWeights: [0.35, 0.65]
                        colMinimums: [90, 60]
                        emptyMessage: qsTr("No scan results yet.")

                        delegate: Rectangle {
                            id: rc
                            required property int row
                            required property int column
                            required property var display

                            implicitHeight: 40
                            color: "transparent"

                            TableCellBackground {
                                cellHovered: false
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: AppTheme.spacingM
                                    right: parent.right
                                    rightMargin: AppTheme.spacingS
                                    verticalCenter: parent.verticalCenter
                                }
                                text: String(rc.display)
                                color: rc.column === 0 ? AppColors.tableCellMuted : AppColors.success
                                font.pixelSize: AppTypography.bodyMedium.pixelSize
                                font.family: AppTypography.monoFamily
                                font.weight: rc.column === 1 ? Font.DemiBold : Font.Normal
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
