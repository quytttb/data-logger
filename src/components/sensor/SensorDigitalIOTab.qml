pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

Rectangle {
    id: root
    color: Theme.bgPanel; radius: Theme.radiusCard
    border.color: Theme.borderDefault; border.width: 1

    signal attachDiRequested(int diSensorId, string diType)
    signal attachDoRequested(int doSensorId, bool trigMax, bool trigMin)
    signal removeDioRequested(int linkId)
    signal updateLinkDiTypeRequested(int linkId, string diType)
    signal updateLinkDoTriggersRequested(int linkId, bool trigMax, bool trigMin)

    property alias dioRepeaterRef: dioRepeater
    property var diSensors: []
    property var doSensors: []

    function sensorOptionLabel(s) {
        return s.name + " (Slave " + s.slaveId + "; Addr " + s.address + ")"
    }

    function diTypeName(code) {
        if (!code) return "—"
        if (code === "00") return "Monitoring"
        if (code === "01") return "Calibrating"
        if (code === "02") return "Error"
        if (code === "03") return "Maintenance"
        return code
    }

    function diTypeCodeFromComboText(text) {
        var t = (text || "").trim()
        return t.indexOf("—") >= 0 ? t.split("—")[0].trim() : t
    }

    readonly property var selectedLink: {
        if (dioListView.currentIndex < 0 || !dioRepeater.model
                || dioListView.currentIndex >= dioRepeater.model.length)
            return null
        return dioRepeater.model[dioListView.currentIndex]
    }

    property bool hasSelectedDio: dioListView.currentIndex >= 0

    function clearSelection() {
        dioListView.currentIndex = -1
    }

    function deleteSelectedDio() {
        if (!selectedLink) return
        var link = selectedLink
        dioDeletePopup.showConfirm(
            "Confirm detach",
            "Detach " + link.ioType + " \"" + link.label + "\" (Slave " + link.slaveId + "; Addr " + link.address + ")?",
            function() {
                root.removeDioRequested(link.id)
                dioListView.currentIndex = -1
            },
            "Detach",
            Theme.btnStop
        )
    }

    onVisibleChanged: {
        if (visible)
            dioListView.currentIndex = -1
    }

    function syncEditPanelFromSelection() {
        if (!selectedLink) return
        if (selectedLink.ioType === "DI") {
            var codes = ["00", "01", "02", "03"]
            var idx = codes.indexOf(selectedLink.diType || "00")
            editDiTypeCombo.currentIndex = idx >= 0 ? idx : 0
        } else if (selectedLink.ioType === "DO") {
            editDoTrigMax.checked = selectedLink.triggerOnMax
            editDoTrigMin.checked = selectedLink.triggerOnMin
        }
    }

    Connections {
        target: dioListView
        function onCurrentIndexChanged() { root.syncEditPanelFromSelection() }
    }

    MessagePopup { id: dioDeletePopup }

    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: Theme.spacingL

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: Theme.spacingSM

            ColumnLayout {
                visible: root.selectedLink !== null
                Layout.fillWidth: true
                spacing: Theme.spacingS

                Text {
                    text: "Edit attachment"
                    color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

                Text {
                    text: root.selectedLink ? root.selectedLink.label : ""
                    color: Theme.textPrimary; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    visible: root.selectedLink !== null
                    text: root.selectedLink
                        ? "Slave " + root.selectedLink.slaveId + " · Addr " + root.selectedLink.address
                        : ""
                    color: Theme.textSecondary; font.pixelSize: AppTypography.labelMedium.pixelSize
                }

                ColumnLayout {
                    visible: root.selectedLink && root.selectedLink.ioType === "DI"
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "Status code:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    ComboBox {
                        id: editDiTypeCombo
                        Layout.fillWidth: true
                        model: ["00 — Monitoring", "01 — Calibrating", "02 — Error", "03 — Maintenance"]
                        onActivated: {
                            if (!root.selectedLink) return
                            root.updateLinkDiTypeRequested(
                                root.selectedLink.id,
                                root.diTypeCodeFromComboText(currentText))
                        }
                    }
                }

                ColumnLayout {
                    visible: root.selectedLink && root.selectedLink.ioType === "DO"
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "Alarm triggers:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                    RowLayout {
                        Layout.fillWidth: true
                        CheckBox {
                            id: editDoTrigMax
                            text: "Trigger on Max"
                            onToggled: {
                                if (!root.selectedLink || root.selectedLink.ioType !== "DO") return
                                root.updateLinkDoTriggersRequested(
                                    root.selectedLink.id, checked, editDoTrigMin.checked)
                            }
                        }
                        CheckBox {
                            id: editDoTrigMin
                            text: "Trigger on Min"
                            onToggled: {
                                if (!root.selectedLink || root.selectedLink.ioType !== "DO") return
                                root.updateLinkDoTriggersRequested(
                                    root.selectedLink.id, editDoTrigMax.checked, checked)
                            }
                        }
                    }
                }

                AppButton {
                    text: "Back to attach"
                    variant: "tonal"
                    Layout.fillWidth: true
                    onClicked: dioListView.currentIndex = -1
                }
            }

            ColumnLayout {
                visible: root.selectedLink === null
                Layout.fillWidth: true
                spacing: Theme.spacingSM

                TabBar {
                    id: attachTypeBar
                    Layout.fillWidth: true
                    background: Rectangle { color: "transparent" }
                    ThemedTabButton { text: "DI"; width: implicitWidth + 30 }
                    ThemedTabButton { text: "DO"; width: implicitWidth + 30 }
                }

                ColumnLayout {
                    visible: attachTypeBar.currentIndex === 0
                    Layout.fillWidth: true; spacing: Theme.spacingS

                    ColumnLayout {
                        visible: root.diSensors.length === 0
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            text: "No Digital Input sensors configured."
                            color: Theme.textFaint; font.pixelSize: AppTypography.bodySmall.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Text {
                            text: "Go to the Sensors tab and add a sensor with register type Discrete Inputs."
                            color: Theme.textFaint; font.pixelSize: AppTypography.labelMedium.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        visible: root.diSensors.length > 0
                        Layout.fillWidth: true; spacing: 8

                        Text { text: "DI sensor:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        ComboBox {
                            id: diSensorCombo
                            Layout.fillWidth: true
                            model: root.diSensors.map(function(s) { return root.sensorOptionLabel(s) })
                        }

                        Text { text: "Status code:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        ComboBox {
                            id: diTypeCombo
                            Layout.fillWidth: true
                            model: ["00 — Monitoring", "01 — Calibrating", "02 — Error", "03 — Maintenance"]
                        }

                        AppButton {
                            text: "Attach DI"
                            Layout.fillWidth: true
                            enabled: diSensorCombo.currentIndex >= 0
                            onClicked: {
                                var idx = diSensorCombo.currentIndex
                                if (idx < 0 || idx >= root.diSensors.length) return
                                root.attachDiRequested(
                                    root.diSensors[idx].id,
                                    root.diTypeCodeFromComboText(diTypeCombo.currentText))
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: attachTypeBar.currentIndex === 1
                    Layout.fillWidth: true; spacing: Theme.spacingS

                    ColumnLayout {
                        visible: root.doSensors.length === 0
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            text: "No Digital Output sensors available."
                            color: Theme.textFaint; font.pixelSize: AppTypography.bodySmall.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Text {
                            text: "Add a Coils sensor in the Sensors tab, or all DOs are linked to other analogs."
                            color: Theme.textFaint; font.pixelSize: AppTypography.labelMedium.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        visible: root.doSensors.length > 0
                        Layout.fillWidth: true; spacing: 8

                        Text { text: "DO sensor:"; color: Theme.textLabel; font.pixelSize: Theme.fontLabelSize }
                        ComboBox {
                            id: doSensorCombo
                            Layout.fillWidth: true
                            model: root.doSensors.map(function(s) { return root.sensorOptionLabel(s) })
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            CheckBox { id: doTrigMax; text: "Trigger on Max"; checked: true }
                            CheckBox { id: doTrigMin; text: "Trigger on Min"; checked: true }
                        }

                        AppButton {
                            text: "Attach DO"
                            Layout.fillWidth: true
                            enabled: doSensorCombo.currentIndex >= 0
                            onClicked: {
                                var idx = doSensorCombo.currentIndex
                                if (idx < 0 || idx >= root.doSensors.length) return
                                root.attachDoRequested(
                                    root.doSensors[idx].id, doTrigMax.checked, doTrigMin.checked)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Attached sensors"
                    color: Theme.accentText; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: dioRepeater.count > 0 ? dioRepeater.count + "" : ""
                    color: Theme.textSecondary; font.pixelSize: AppTypography.bodySmall.pixelSize
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderDefault }

            ListView {
                id: dioListView
                smooth: false
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: dioRepeater.model
                currentIndex: -1

                delegate: Rectangle {
                    id: linkRow
                    required property int index
                    required property var modelData

                    width: ListView.view.width
                    height: 48
                    radius: Theme.radiusTiny
                    color: linkRow.modelData.ioType === "DO" ? AppColors.doTint : AppColors.diTint
                    border.color: ListView.view.currentIndex === linkRow.index ? Theme.accent : "transparent"
                    border.width: ListView.view.currentIndex === linkRow.index ? 2 : 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: ListView.view.currentIndex = linkRow.index
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: Theme.spacingSM

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusTiny
                            color: linkRow.modelData.ioType === "DO" ? Theme.btnStop : Theme.btnStart
                            Text {
                                anchors.centerIn: parent
                                text: linkRow.modelData.ioType
                                color: "#FFF"
                                font.bold: true
                                font.pixelSize: AppTypography.bodySmall.pixelSize
                            }
                        }

                        Text {
                            text: linkRow.modelData.label
                            color: Theme.textPrimary
                            font.pixelSize: AppTypography.titleSmall.pixelSize
                            Layout.fillWidth: true
                            Layout.minimumWidth: 60
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            visible: linkRow.modelData.ioType === "DI"
                            text: root.diTypeName(linkRow.modelData.diType)
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontLabelSize
                            Layout.preferredWidth: implicitWidth
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            visible: linkRow.modelData.ioType === "DO"
                            text: {
                                var parts = []
                                if (linkRow.modelData.triggerOnMax) parts.push("Max")
                                if (linkRow.modelData.triggerOnMin) parts.push("Min")
                                return parts.length ? parts.join(", ") : "—"
                            }
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontLabelSize
                            Layout.preferredWidth: implicitWidth
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Slave " + linkRow.modelData.slaveId + " · Addr " + linkRow.modelData.address
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontLabelSize
                            Layout.preferredWidth: implicitWidth
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                Text {
                    visible: dioListView.count === 0
                    anchors.centerIn: parent
                    width: parent.width - 20
                    text: "No digital sensors attached.\nSelect DI or DO on the left to attach."
                    color: Theme.textFaint; font.pixelSize: AppTypography.bodyMedium.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Repeater {
        id: dioRepeater
        delegate: Item { visible: false }
    }
}
