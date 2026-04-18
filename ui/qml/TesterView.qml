import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: testerRoot
    anchors.fill: parent

    property bool narrow: width < 700
    property bool connVisited: true
    property bool opsVisited: false
    property bool pendingScanLoad: false

    property string errorDialogTitle: ""
    property string errorDialogMessage: ""

    function showError(title, msg) {
        errorDialogTitle = title
        errorDialogMessage = msg
        errorDialog.open()
    }

    function showToast(title, msg) {
        toastTitleLabel.text = title
        toastMsgLabel.text = msg
        toastPopup.open()
    }

    // ── Lỗi: Dialog modal (bắt buộc xác nhận) ───────────────────────────
    Dialog {
        id: errorDialog
        parent: Overlay.overlay
        modal: true
        title: testerRoot.errorDialogTitle
        width: Overlay.overlay ? Math.min(420, Overlay.overlay.width - 40) : 420
        x: Overlay.overlay ? Math.round((Overlay.overlay.width - width) / 2) : 0
        y: Overlay.overlay ? Math.round((Overlay.overlay.height - height) / 2) : 0
        standardButtons: Dialog.Ok

        contentItem: Label {
            text: testerRoot.errorDialogMessage
            wrapMode: Text.WordWrap
            width: Overlay.overlay ? Math.min(380, Overlay.overlay.width - 64) : 380
            padding: 4
            color: Theme.textPrimary
            font.pixelSize: 14
        }
    }

    // ── Thành công / thông tin: toast không chặn UI ───────────────────────
    Popup {
        id: toastPopup
        parent: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        width: Overlay.overlay ? Math.min(440, Overlay.overlay.width - 24) : 440
        x: Overlay.overlay ? Math.round((Overlay.overlay.width - width) / 2) : 0
        y: 72
        padding: 12

        background: Rectangle {
            color: Theme.bgPanel
            radius: 8
            border.color: Theme.statusOk
            border.width: 2
        }

        contentItem: ColumnLayout {
            spacing: 8
            width: toastPopup.availableWidth
            Label {
                id: toastTitleLabel
                font.bold: true
                font.pixelSize: 14
                color: Theme.textPrimary
                Layout.fillWidth: true
            }
            Label {
                id: toastMsgLabel
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: Theme.accentText
                Layout.fillWidth: true
            }
        }

        Timer {
            id: toastTimer
            interval: 2800
            repeat: false
            onTriggered: toastPopup.close()
        }
        onOpened: toastTimer.restart()
    }

    // ── Save Sensor Dialog ────────────────────────────────────────────────
    Popup {
        id: saveSensorDialog
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 16)
        height: Math.min(400, parent.height - 24)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.bgPanel
            radius: Theme.radiusCard
            border.color: Theme.accent
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10
            Text {
                text: qsTr("Save new sensor")
                color: Theme.accentText
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: saveGrid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: saveGrid
                    columns: 2
                    width: parent.width
                    columnSpacing: 10
                    rowSpacing: 8

                    Label { text: qsTr("Name:"); color: Theme.textSecondary }
                    TextField {
                        id: sensorNameInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                    }

                    Label { text: qsTr("Unit:"); color: Theme.textSecondary }
                    TextField {
                        id: sensorUnitInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                    }

                    Label { text: qsTr("Coefficients (JSON):"); color: Theme.textSecondary }
                    TextField {
                        id: sensorCoeffInput
                        Layout.fillWidth: true
                        text: "{}"
                        color: Theme.textPrimary
                        background: Rectangle { color: Theme.bgInput; radius: Theme.radiusTiny }
                    }

                    Label { text: qsTr("Poll interval (s):"); color: Theme.textSecondary }
                    SpinBox { id: sensorPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true }

                    Label { text: qsTr("Report column:"); color: Theme.textSecondary }
                    SpinBox { id: sensorReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true }

                    Rectangle { Layout.columnSpan: 2; Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

                    Label { text: qsTr("Slave ID:"); color: "#666" }
                    Text { id: infoSlaveId; color: Theme.textSecondary; font.pixelSize: 14 }
                    Label { text: qsTr("Start address:"); color: "#666" }
                    Text { id: infoAddr; color: Theme.textSecondary; font.pixelSize: 14 }
                    Label { text: qsTr("Register type:"); color: "#666" }
                    Text { id: infoRegType; color: Theme.textSecondary; font.pixelSize: 14 }
                    Label { text: qsTr("Data type:"); color: "#666" }
                    Text { id: infoDataType; color: Theme.textSecondary; font.pixelSize: 14 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: qsTr("Cancel")
                    Layout.fillWidth: true
                    onClicked: saveSensorDialog.close()
                }
                Button {
                    text: qsTr("Save sensor")
                    Layout.fillWidth: true
                    onClicked: {
                        if (!connLoader.item || !opsLoader.item)
                            return
                        var regMap = { "Holding Register": "holding", "Input Register": "input" }
                        var dtMap = { "Decimal": "uint16", "Float": "float32", "Swapped Float": "float32" }
                        var fmtMap = { "Decimal": "AB", "Float": "ABCD", "Swapped Float": "CDAB" }
                        var c = connLoader.item
                        var o = opsLoader.item
                        settingsController.save_serial_config(
                            c.portCombo.currentText,
                            parseInt(c.baudCombo.currentText),
                            c.dataBitsSpin.value,
                            c.parityCombo.currentText,
                            parseInt(c.stopBitsCombo.currentText)
                        )
                        sensorModel.add_sensor(
                            sensorNameInput.text,
                            sensorUnitInput.text,
                            c.slaveSpin.value,
                            o.scanStartSpin.value,
                            regMap[o.regTypeCombo.currentText] || "holding",
                            dtMap[o.dataTypeCombo.currentText] || "uint16",
                            fmtMap[o.dataTypeCombo.currentText] || "AB",
                            sensorCoeffInput.text,
                            sensorPollInterval.value,
                            sensorReportIdx.value,
                            true
                        )
                        saveSensorDialog.close()
                    }
                }
            }
        }
    }

    function openSaveSensorDialog() {
        opsVisited = true
        pendingScanLoad = true
        Qt.callLater(function () {
            pendingScanLoad = false
            if (!connLoader.item || !opsLoader.item) {
                showError(qsTr("Error"), qsTr("Could not load configuration tabs."))
                return
            }
            fillSaveDialogFields()
            saveSensorDialog.open()
        })
    }

    function fillSaveDialogFields() {
        var c = connLoader.item
        var o = opsLoader.item
        if (!c || !o)
            return
        sensorNameInput.text = ""
        sensorUnitInput.text = ""
        sensorCoeffInput.text = "{}"
        sensorPollInterval.value = 3
        sensorReportIdx.value = 0
        infoSlaveId.text = String(c.slaveSpin.value)
        infoAddr.text = String(o.scanStartSpin.value)
        infoRegType.text = o.regTypeCombo.currentText
        infoDataType.text = o.dataTypeCombo.currentText
    }

    function performScan() {
        if (!connLoader.item || !opsLoader.item) {
            showError(qsTr("Error"), qsTr("Configuration is still loading. Try again."))
            return
        }
        if (!testerController.isConnected) {
            showError(qsTr("Error"), qsTr("Not connected to Modbus."))
            return
        }
        var o = opsLoader.item
        if (o.scanStartSpin.value > o.scanEndSpin.value) {
            showError(qsTr("Error"), qsTr("Start address must be less than or equal to end address."))
            return
        }
        scanModel.clear()
        testerController.start_scan(
            o.scanStartSpin.value,
            o.scanEndSpin.value,
            o.scanCountSpin.value,
            o.regTypeCombo.currentText,
            o.dataTypeCombo.currentText,
            connLoader.item.slaveSpin.value
        )
    }

    function connectOrDisconnect() {
        if (!connLoader.item)
            return
        var c = connLoader.item
        if (testerController.isConnected)
            testerController.disconnect_serial()
        else
            testerController.connect_serial(
                c.portCombo.currentText,
                parseInt(c.baudCombo.currentText),
                c.dataBitsSpin.value,
                c.parityCombo.currentText,
                parseInt(c.stopBitsCombo.currentText)
            )
    }

    function clearResultsTable() {
        scanModel.clear()
    }

    function toggleScan() {
        if (testerController.isScanning) {
            testerController.stop_scan()
        } else {
            pendingScanLoad = true
            opsVisited = true
            Qt.callLater(function () {
                pendingScanLoad = false
                performScan()
            })
        }
    }

    Connections {
        target: testerController
        function onMessageReceived(title, msg, isError) {
            if (isError)
                showError(title, msg)
            else
                showToast(title, msg)
        }
        function onScanResultReceived(addr, val) {
            scanModel.append({ "address": addr, "value": val })
        }
    }

    ListModel { id: scanModel }

    SplitView {
        id: split
        anchors.fill: parent
        orientation: testerRoot.narrow ? Qt.Vertical : Qt.Horizontal

        ScrollView {
            id: leftScroll
            clip: true
            SplitView.minimumWidth: 260
            SplitView.preferredWidth: testerRoot.narrow ? -1 : 340
            SplitView.preferredHeight: testerRoot.narrow ? 380 : -1
            SplitView.fillWidth: testerRoot.narrow
            SplitView.fillHeight: !testerRoot.narrow

            ColumnLayout {
                id: leftColumn
                width: leftScroll.availableWidth
                spacing: 8

                TabBar {
                    id: testerTabBar
                    Layout.fillWidth: true
                    currentIndex: 0

                    TabButton { text: qsTr("Connection") }
                    TabButton { text: qsTr("Operations") }

                    onCurrentIndexChanged: {
                        if (currentIndex === 1)
                            testerRoot.opsVisited = true
                    }
                }

                StackLayout {
                    id: tabStackLayout
                    Layout.fillWidth: true
                    Layout.preferredHeight: {
                        if (testerTabBar.currentIndex === 0)
                            return connLoader.item ? Math.max(connLoader.item.implicitHeight, 120) : 200
                        return opsLoader.item ? Math.max(opsLoader.item.implicitHeight, 120) : 200
                    }
                    currentIndex: testerTabBar.currentIndex

                    Loader {
                        id: connLoader
                        active: testerRoot.connVisited
                        width: tabStackLayout.width
                        source: "TesterConnectionTab.qml"
                    }

                    Loader {
                        id: opsLoader
                        active: testerRoot.opsVisited || testerRoot.pendingScanLoad
                        width: tabStackLayout.width
                        source: "TesterOperationsTab.qml"
                    }
                }
            }
        }

        Pane {
            id: rightPane
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            padding: 10

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                Label {
                    text: qsTr("Scan results")
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.accentText
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bgDeep
                    border.color: Theme.borderDefault
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            Label {
                                text: qsTr("Address")
                                color: Theme.accent
                                font.bold: true
                                font.pixelSize: 13
                                Layout.preferredWidth: 100
                            }
                            Label {
                                text: qsTr("Value")
                                color: Theme.accent
                                font.bold: true
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: scanModel
                            clip: true
                            spacing: 2

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                color: index % 2 === 0 ? Theme.bgPanel : Theme.bgSeparator
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    Text {
                                        text: model.address
                                        color: Theme.textPrimary
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 100
                                    }
                                    Text {
                                        text: model.value
                                        color: Theme.statusOk
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
