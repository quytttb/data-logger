import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// TAB 2: Digital I/O
Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    signal addDioFormSubmitted(string ioType, string label, string diType, int slave, int addr, bool trigMax, bool trigMin)
    signal removeDioRequested(int dioId)

    property alias dioRepeaterRef: dioRepeater

    property var diTypeMap: {
        "Monitoring": "00",
        "Calibrating": "01",
        "Error": "02",
        "Maintenance": "03"
    }

    onVisibleChanged: {
        if (visible) {
            dioListView.currentIndex = -1
            _cancelDioEdit()
        }
    }

    // Confirm delete popup
    MessagePopup {
        id: dioDeletePopup
    }

    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: 20

        // ── LEFT: Add/Edit Form ──
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 12

            // DI / DO Tab selector
            TabBar {
                id: dioTypeTabBar
                Layout.fillWidth: true

                TabButton {
                    text: "DI"
                    width: implicitWidth + 30
                }
                TabButton {
                    text: "DO"
                    width: implicitWidth + 30
                }
            }

            GridLayout {
                columns: 2; Layout.fillWidth: true; columnSpacing: 10; rowSpacing: 10

                Text { text: "Label:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                ComboBox {
                    id: newDioLabelPreset
                    model: ["Monitoring", "Calibrating", "Error", "Maintenance", "Custom"]
                    Layout.fillWidth: true
                }

                Text {
                    text: "Custom label:"
                    color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                    visible: newDioLabelPreset.currentText === "Custom"
                }
                AppTextField {
                    id: newDioLabelCustom
                    Layout.fillWidth: true
                    placeholderText: "Enter custom label"
                    visible: newDioLabelPreset.currentText === "Custom"
                }

                Text {
                    text: "Label ID:"
                    color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize
                    visible: dioTypeTabBar.currentIndex === 0 && newDioLabelPreset.currentText === "Custom" // Only show for Custom DI
                }
                AppTextField {
                    id: newDioTypeCustom
                    Layout.fillWidth: true
                    placeholderText: "Exclude 00, 01, 02, 03"
                    visible: dioTypeTabBar.currentIndex === 0 && newDioLabelPreset.currentText === "Custom"
                    validator: RegularExpressionValidator { regularExpression: /^[0-9]+$/ }
                }

                Text { text: "Slave ID:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                SpinBox { id: newDioSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true; editable: true }

                Text { text: "Address:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                SpinBox { id: newDioAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }

                Text { text: "Trigger on Max:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: dioTypeTabBar.currentIndex === 1 }
                Switch { id: newDioTrigMax; checked: true; visible: dioTypeTabBar.currentIndex === 1 }

                Text { text: "Trigger on Min:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize; visible: dioTypeTabBar.currentIndex === 1 }
                Switch { id: newDioTrigMin; checked: true; visible: dioTypeTabBar.currentIndex === 1 }
            }

            Item { Layout.fillHeight: true }

            // ADD button (normal mode) — blue accent
            Button {
                visible: !root._dioEditMode
                text: "ADD " + (dioTypeTabBar.currentIndex === 0 ? "DI" : "DO")
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                font.bold: true
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.accent
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: Theme.textOnColoredBtn
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var presetText = newDioLabelPreset.currentText
                    var label = presetText === "Custom"
                        ? newDioLabelCustom.text.trim()
                        : presetText
                    if (label === "") return
                    
                    var ioType = dioTypeTabBar.currentIndex === 0 ? "DI" : "DO"
                    var diType = "" // Only for DI
                    if (ioType === "DI") {
                        if (presetText === "Custom") {
                            diType = newDioTypeCustom.text.trim()
                        } else {
                            diType = root.diTypeMap[presetText] !== undefined ? root.diTypeMap[presetText] : ""
                        }
                    }

                    root.addDioFormSubmitted(ioType, label, diType, newDioSlave.value, newDioAddr.value, newDioTrigMax.checked, newDioTrigMin.checked)
                    root._resetDioForm()
                }
            }

            // SAVE + CANCEL buttons (edit mode)
            RowLayout {
                visible: root._dioEditMode
                Layout.fillWidth: true
                spacing: 8

                Button {
                    text: "CANCEL"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    font.bold: true
                    onClicked: root._cancelDioEdit()
                }

                Button {
                    text: "SAVE"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    font.bold: true
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: Theme.btnStart
                        opacity: parent.pressed ? 0.75 : 1.0
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font
                        color: Theme.textOnColoredBtn
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root._saveDioEdit()
                }
            }
        }

        // Divider
        Rectangle { width: 1; Layout.fillHeight: true; color: Theme.borderDefault }

        // ── RIGHT: List ──
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Configured I/O"; color: Theme.accentText; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true }
                Text {
                    text: dioRepeater.count > 0 ? dioRepeater.count + " item(s)" : ""
                    color: Theme.textSecondary; font.pixelSize: 13
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderDefault }

            ListView {
                id: dioListView
                smooth: false
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: dioRepeater.model
                currentIndex: -1

                delegate: Rectangle {
                    width: dioListView.width; height: 40; radius: 4
                    color: modelData.ioType === "DO" ? "#301010" : "#103010"
                    border.color: dioListView.currentIndex === index ? Theme.accent : "transparent"
                    border.width: dioListView.currentIndex === index ? 2 : 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            dioListView.currentIndex = (dioListView.currentIndex === index) ? -1 : index
                        }
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 8
                        Rectangle {
                            width: 36; height: 24; radius: 4
                            color: modelData.ioType === "DO" ? Theme.btnStop : Theme.btnStart
                            Text {
                                anchors.centerIn: parent
                                text: modelData.ioType; color: "#FFF"; font.bold: true; font.pixelSize: 12
                            }
                        }
                        Text { text: modelData.label + (modelData.diType ? " (ID: " + modelData.diType + ")" : ""); color: Theme.textPrimary; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "Slave " + modelData.slaveId + " / Addr " + modelData.address; color: Theme.textSecondary; font.pixelSize: 12 }
                    }
                }

                // Empty state
                Text {
                    visible: dioListView.count === 0
                    anchors.centerIn: parent
                    text: "No digital I/O pins configured.\nUse the form on the left to add DI or DO."
                    color: Theme.textFaint; font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Hidden Repeater to maintain dioRepeater alias compatibility
    Repeater {
        id: dioRepeater
        delegate: Item { visible: false }
    }

    // ── DIO edit mode state ──────────────────────────────────────────────
    property bool _dioEditMode: false
    property int _dioEditId: -1

    // Expose selected DIO index and data for toolbar buttons
    property int currentDioIndex: dioListView ? dioListView.currentIndex : -1
    property bool hasSelectedDio: currentDioIndex >= 0

    function getSelectedDioId() {
        if (currentDioIndex < 0 || !dioRepeater.model || currentDioIndex >= dioRepeater.model.length)
            return -1
        return dioRepeater.model[currentDioIndex].id
    }

    function editSelectedDio() {
        if (currentDioIndex < 0 || !dioRepeater.model || currentDioIndex >= dioRepeater.model.length)
            return
        var dio = dioRepeater.model[currentDioIndex]
        _dioEditMode = true
        _dioEditId = dio.id

        // Populate form with existing data
        dioTypeTabBar.currentIndex = dio.ioType === "DO" ? 1 : 0

        // Set label preset or custom (detect by label or diType)
        var presetIdx = newDioLabelPreset.model.indexOf(dio.label)
        if (presetIdx >= 0 && presetIdx < 4) {
            newDioLabelPreset.currentIndex = presetIdx
            newDioLabelCustom.text = ""
            newDioTypeCustom.text = ""
        } else {
            newDioLabelPreset.currentIndex = 4 // Custom
            newDioLabelCustom.text = dio.label
            newDioTypeCustom.text = dio.diType || ""
        }

        newDioSlave.value = dio.slaveId
        newDioAddr.value = dio.address
        if (dio.ioType === "DO") {
            newDioTrigMax.checked = dio.triggerOnMax
            newDioTrigMin.checked = dio.triggerOnMin
        }
    }

    function deleteSelectedDio() {
        if (currentDioIndex < 0 || !dioRepeater.model || currentDioIndex >= dioRepeater.model.length)
            return
        var dio = dioRepeater.model[currentDioIndex]
        dioDeletePopup.showConfirm(
            "Confirm delete",
            "Delete " + dio.ioType + " \"" + dio.label + "\" (Slave " + dio.slaveId + " / Addr " + dio.address + ")?",
            function() {
                root.removeDioRequested(dio.id)
                dioListView.currentIndex = -1
            },
            "Delete",
            Theme.btnStop
        )
    }

    function _cancelDioEdit() {
        _dioEditMode = false
        _dioEditId = -1
        _resetDioForm()
    }

    function _saveDioEdit() {
        var presetText = newDioLabelPreset.currentText
        var label = presetText === "Custom"
            ? newDioLabelCustom.text.trim()
            : presetText
        if (label === "") return

        var ioType = dioTypeTabBar.currentIndex === 0 ? "DI" : "DO"
        var diType = "" // Only for DI
        if (ioType === "DI") {
            if (presetText === "Custom") {
                diType = newDioTypeCustom.text.trim()
            } else {
                diType = root.diTypeMap[presetText] !== undefined ? root.diTypeMap[presetText] : ""
            }
        }

        // Remove old, add new (update = delete + insert)
        if (_dioEditId >= 0) {
            root.removeDioRequested(_dioEditId)
        }
        root.addDioFormSubmitted(ioType, label, diType, newDioSlave.value, newDioAddr.value, newDioTrigMax.checked, newDioTrigMin.checked)

        _dioEditMode = false
        _dioEditId = -1
        _resetDioForm()
        dioListView.currentIndex = -1
    }

    function _resetDioForm() {
        newDioLabelPreset.currentIndex = 0
        newDioLabelCustom.text = ""
        newDioTypeCustom.text = ""
        newDioSlave.value = 1
        newDioAddr.value = 0
        newDioTrigMax.checked = true
        newDioTrigMin.checked = true
    }
}
