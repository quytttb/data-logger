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
        var result = TesterController.write_single(regType, addr, valStr, slaveId, dataType)
        if (result === "SUCCESS") {
            showToast("Write OK", "Wrote " + valStr + " to address " + addr)

            var found = false
            for (var i = 0; i < scanModel.count; i++) {
                if (scanModel.get(i).address === addr) {
                    scanModel.setProperty(i, "value", valStr)
                    found = true
                    break
                }
            }
            if (!found) {
                scanModel.append({ "address": addr, "value": valStr })
            }
            _rebuildFiltered()
        } else {
            showError("Write Error", result)
        }
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
    }

    ListModel { id: scanModel }
    ListModel { id: filteredModel }

    function _rebuildFiltered() {
        filteredModel.clear()
        for (var i = 0; i < scanModel.count; i++) {
            var item = scanModel.get(i)
            if (testerRoot.hideZeros && testerRoot._isZeroValue(item.value))
                continue
            filteredModel.append({ "address": item.address, "value": item.value })
        }
    }

    function _isZeroValue(val) {
        var s = String(val).trim()
        if (s === "0" || s === "0.0" || s === "0.00" || s === "0.000" || s === "0.0000") return true
        var m = s.match(/^\[([\d,\s]*)\]$/)
        if (m) {
            var nums = m[1].split(",")
            for (var i = 0; i < nums.length; i++) {
                if (parseInt(nums[i].trim()) !== 0) return false
            }
            return true
        }
        return false
    }

    onHideZerosChanged: _rebuildFiltered()

    SplitView {
        id: split
        anchors.fill: parent
        orientation: testerRoot.narrow ? Qt.Vertical : Qt.Horizontal

        ScrollView {
            id: leftScroll; clip: true
            SplitView.minimumWidth: 260
            SplitView.preferredWidth: testerRoot.narrow ? -1 : 340
            SplitView.preferredHeight: testerRoot.narrow ? 380 : -1
            SplitView.fillWidth: testerRoot.narrow
            SplitView.fillHeight: !testerRoot.narrow

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
                            color: Theme.textPrimary; font.pixelSize: 13; font.bold: true
                        }
                        Text {
                            text: SettingsController.serialBytesize + "bit, Parity:" + SettingsController.serialParity + ", Stop:" + SettingsController.serialStopbits
                            color: Theme.textSecondary; font.pixelSize: 12
                        }
                    }
                }

                TesterOperationsTab {
                    id: opsTab
                    Layout.fillWidth: true
                }
            }
        }

        Pane {
            SplitView.fillWidth: true; SplitView.fillHeight: true; padding: 10

            ColumnLayout {
                anchors.fill: parent; spacing: 8

                Label { text: "Scan results"; font.pixelSize: 14; font.bold: true; color: Theme.accentText; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgDeep; border.color: Theme.borderDefault; radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 0

                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 28
                            Label { text: "Address"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 100 }
                            Label { text: "Value"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                        }

                        ListView {
                            id: resultsListView
                            Layout.fillWidth: true; Layout.fillHeight: true
                            model: filteredModel; clip: true; spacing: 2
                            delegate: Rectangle {
                                id: resultRow
                                required property int index
                                required property int address
                                required property string value

                                width: ListView.view.width; height: 36
                                color: resultRow.index % 2 === 0 ? Theme.bgPanel : Theme.bgSeparator
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 5
                                    Text { text: resultRow.address; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 100 }
                                    Text { text: resultRow.value; color: Theme.statusOk; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
