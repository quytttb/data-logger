import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Components

Item {
    id: testerRoot
    anchors.fill: parent

    property bool narrow: width < 700
    property bool hideZeros: false
    // Expose Operations tab item cho TaskBar truy cập isWritableType
    readonly property var opsItem: opsLoader.item

    signal navigateToAddSensor(var data)
    function showError(title, msg) {
        errorDialog.showMessage(title, msg)
    }

    function showToast(title, msg) {
        toastPopup.showToast(title, msg)
    }

    // ── Error Dialog ──────────────────────────────────────────────────
    MessagePopup {
        id: errorDialog
    }

    // ── Toast Popup ───────────────────────────────────────────────────
    ToastPopup {
        id: toastPopup
    }

    // ── Navigate to Settings > Add Sensor with Tester data ─────────────
    function openSaveSensorInSettings() {
        if (!opsLoader.item) {
            showError("Error", "Operations tab not loaded.")
            return
        }
        var o = opsLoader.item

        // Tester giờ dùng cùng tên option với SensorConfigForm → truyền thẳng
        var data = {
            slaveId: o.slaveSpin.value,
            registerAddress: o.scanStartSpin.value,
            registerType: o.regTypeCombo.currentText,
            dataType: o.dataTypeCombo.currentText,
            dataFormat: o.dataFormatCombo.currentText
        }

        navigateToAddSensor(data)
    }

    // ── Connect/Disconnect uses global settingsController (Modbus Master) ──
    function connectOrDisconnect() {
        if (testerController.isConnected)
            testerController.disconnect_serial()
        else
            testerController.connect_serial(
                settingsController.serialPort,
                settingsController.serialBaudrate,
                settingsController.serialBytesize,
                settingsController.serialParity,
                settingsController.serialStopbits
            )
    }

    function performScan() {
        if (!opsLoader.item) {
            showError("Error", "Operations tab is still loading.")
            return
        }
        if (!testerController.isConnected) {
            showError("Error", "Not connected to Modbus. Check Connection settings.")
            return
        }
        var o = opsLoader.item
        if (o.scanStartSpin.value > o.scanEndSpin.value) {
            showError("Error", "Start address must be ≤ end address.")
            return
        }
        scanModel.clear()
        testerController.start_scan(
            o.scanStartSpin.value, o.scanEndSpin.value, o.scanCountSpin.value,
            o.regTypeCombo.currentText, o.dataTypeCombo.currentText,
            o.slaveSpin.value, o.dataFormatCombo.currentText
        )
    }

    function performWrite() {
        if (!opsLoader.item) {
            showError("Error", "Operations tab not loaded.")
            return
        }
        if (!testerController.isConnected) {
            showError("Error", "Not connected to Modbus.")
            return
        }
        var o = opsLoader.item
        var addr = o.writeAddrSpin.value
        var valStr = String(o.writeValSpin.value)
        var regType = o.regTypeCombo.currentText
        var dataType = o.isBooleanType ? "uint16" : o.dataTypeCombo.currentText
        var slaveId = o.slaveSpin.value
        var result = testerController.write_single(regType, addr, valStr, slaveId, dataType)
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
        if (testerController.isScanning)
            testerController.stop_scan()
        else
            performScan()
    }

    Connections {
        target: testerController
        function onMessageReceived(title, msg, isError) {
            if (isError) showError(title, msg)
            else showToast(title, msg)
        }
        function onScanResultReceived(addr, val) {
            scanModel.append({ "address": addr, "value": val })
            if (!hideZeros || !_isZeroValue(val))
                filteredModel.append({ "address": addr, "value": val })
        }
    }

    ListModel { id: scanModel }

    // Model đã lọc (ẩn hàng có giá trị 0)
    ListModel { id: filteredModel }

    function _rebuildFiltered() {
        filteredModel.clear()
        for (var i = 0; i < scanModel.count; i++) {
            var item = scanModel.get(i)
            if (hideZeros && _isZeroValue(item.value))
                continue
            filteredModel.append({ "address": item.address, "value": item.value })
        }
    }

    function _isZeroValue(val) {
        // Kiểm tra giá trị 0: "0", "0.0", "0.0000", "[0]", "[0, 0]", v.v.
        var s = String(val).trim()
        if (s === "0" || s === "0.0" || s === "0.00" || s === "0.000" || s === "0.0000") return true
        // Dạng list: [0], [0, 0], [0, 0, 0, ...]
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

    // ── Main Layout ──────────────────────────────────────────────────
    SplitView {
        id: split
        anchors.fill: parent
        orientation: testerRoot.narrow ? Qt.Vertical : Qt.Horizontal

        // LEFT: Operations only (Connection tab removed — uses global Master config)
        ScrollView {
            id: leftScroll; clip: true
            SplitView.minimumWidth: 260
            SplitView.preferredWidth: testerRoot.narrow ? -1 : 340
            SplitView.preferredHeight: testerRoot.narrow ? 380 : -1
            SplitView.fillWidth: testerRoot.narrow
            SplitView.fillHeight: !testerRoot.narrow

            ColumnLayout {
                width: leftScroll.availableWidth; spacing: 8

                // Info banner: shows current Master serial config
                Rectangle {
                    Layout.fillWidth: true; height: infoBanner.implicitHeight + 16
                    color: Theme.bgSeparator; radius: Theme.radiusTiny
                    border.color: Theme.borderDefault; border.width: 1

                    ColumnLayout {
                        id: infoBanner
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Text {
                            text: "Serial: " + settingsController.serialPort + " @ " + settingsController.serialBaudrate + " baud"
                            color: Theme.textPrimary; font.pixelSize: 13; font.bold: true
                        }
                        Text {
                            text: settingsController.serialBytesize + "bit, Parity:" + settingsController.serialParity + ", Stop:" + settingsController.serialStopbits
                            color: Theme.textSecondary; font.pixelSize: 12
                        }
                    }
                }

                Loader {
                    id: opsLoader
                    active: true
                    Layout.fillWidth: true
                    source: "TesterOperationsTab.qml"
                }
            }
        }

        // RIGHT: Scan results table
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
                            Layout.fillWidth: true; Layout.fillHeight: true
                            model: filteredModel; clip: true; spacing: 2
                            delegate: Rectangle {
                                width: ListView.view.width; height: 36
                                color: index % 2 === 0 ? Theme.bgPanel : Theme.bgSeparator
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 5
                                    Text { text: model.address; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 100 }
                                    Text { text: model.value; color: Theme.statusOk; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
