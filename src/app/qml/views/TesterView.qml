pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

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
        if (TesterController.isConnected)
            TesterController.disconnectSerial()
        else
            TesterController.connectSerial(
                SettingsController.serialPort,
                SettingsController.serialBaudrate,
                SettingsController.serialBytesize,
                SettingsController.serialParity,
                SettingsController.serialStopbits
            )
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

    function clearResultsTable() { scanModel.clear(); filteredModel.clear() }

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
                filteredModel.append({ "address": addr, "value": val })
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

    ListModel { id: scanModel }
    ListModel { id: filteredModel }

    function _rebuildFiltered() {
        filteredModel.clear()
        for (let i = 0; i < scanModel.count; i++) {
            let item = scanModel.get(i)
            if (testerRoot.hideZeros && testerRoot._isZeroValue(item.value))
                continue
            filteredModel.append({ "address": item.address, "value": item.value })
        }
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
                    color: Theme.bgSeparator; radius: Theme.radiusTiny
                    border.color: Theme.borderDefault; border.width: 1

                    ColumnLayout {
                        id: infoBanner
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text {
                            text: "Serial: " + SettingsController.serialPort + " @ " + SettingsController.serialBaudrate + " baud"
                            color: Theme.textPrimary; font.pixelSize: AppTypography.bodySmall.pixelSize; font.bold: true
                        }
                        Text {
                            text: SettingsController.serialBytesize + "bit, Parity:" + SettingsController.serialParity + ", Stop:" + SettingsController.serialStopbits
                            color: Theme.textSecondary; font.pixelSize: AppTypography.labelMedium.pixelSize
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
            Layout.fillWidth: true; Layout.fillHeight: true; padding: Theme.spacingS
            background: null

            ColumnLayout {
                anchors.fill: parent; spacing: 8

                Label { text: "Scan results"; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true; color: Theme.accentText; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: AppColors.surfaceContainerLow
                    border.color: AppColors.elevatedBorder
                    radius: AppTheme.cardRadius
                    clip: true

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
                                anchors.leftMargin: 16; anchors.rightMargin: 16
                                spacing: 8
                                Label { text: "Address"; color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.preferredWidth: 100 }
                                Label { text: "Value"; color: AppColors.tableHeaderText; font: AppTypography.labelLarge; Layout.fillWidth: true }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: AppColors.outline
                            }
                        }

                        ListView {
                            id: resultsListView
                            Layout.fillWidth: true; Layout.fillHeight: true
                            model: filteredModel; clip: true; spacing: 0
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                id: resultRow
                                required property int index
                                required property int address
                                required property string value

                                width: ListView.view.width; height: 40
                                color: "transparent"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: AppColors.outlineVariant
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16; anchors.rightMargin: 16
                                    spacing: 8
                                    Text { text: resultRow.address; color: AppColors.tableCellMuted; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.family: AppTypography.monoFamily; Layout.preferredWidth: 100 }
                                    Text { text: resultRow.value; color: AppColors.success; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.family: AppTypography.monoFamily; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
