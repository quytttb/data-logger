pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: root
    color: AppColors.surfaceContainerLow; radius: AppTheme.cardRadius
    border.color: AppColors.outlineVariant; border.width: 1

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
        const m = dioRepeater.model
        if (!m || dioListView.currentIndex < 0 || dioListView.currentIndex >= m.length)
            return null
        return m[dioListView.currentIndex]
    }

    // Sticky selection across model refresh — ListView resets currentIndex khi
    // Repeater model thay bằng array mới. Lưu id và khôi phục sau khi gán model.
    property int _pendingSelectId: -1

    property bool hasSelectedDio: selectedLink !== null

    function clearSelection() {
        _pendingSelectId = -1
        dioListView.currentIndex = -1
    }

    function restoreSelectionById(linkId) {
        const m = dioRepeater.model
        if (!m || linkId < 0) return
        for (let i = 0; i < m.length; ++i) {
            if (m[i].id === linkId) { dioListView.currentIndex = i; break }
        }
    }

    function deleteSelectedDio() {
        if (!selectedLink) return
        const linkId = selectedLink.id
        const linkIo = selectedLink.ioType
        const linkLabel = selectedLink.label
        const linkSlave = selectedLink.slaveId
        const linkAddr = selectedLink.address
        _pendingSelectId = -1
        dioDeletePopup.showConfirm(
            "Confirm detach",
            "Detach " + linkIo + " \"" + linkLabel + "\" (Slave " + linkSlave + "; Addr " + linkAddr + ")?",
            function() {
                root.removeDioRequested(linkId)
                // selection được clear trong onRemove handler qua _refreshLinks
            },
            "Detach",
            AppColors.error
        )
    }

    onVisibleChanged: {
        if (visible)
            dioListView.currentIndex = -1
        else
            _pendingSelectId = -1
    }

    function syncEditPanelFromSelection() {
        if (!selectedLink) return
        if (selectedLink.ioType === "DI") {
            let codes = ["00", "01", "02", "03"]
            let idx = codes.indexOf(selectedLink.diType || "00")
            editDiTypeCombo.currentIndex = idx >= 0 ? idx : 0
        } else if (selectedLink.ioType === "DO") {
            editDoTrigMax.checked = selectedLink.triggerOnMax
            editDoTrigMin.checked = selectedLink.triggerOnMin
        }
    }

    MessagePopup { id: dioDeletePopup }

    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: AppTheme.spacingL

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: AppTheme.spacingSM

            ColumnLayout {
                visible: root.selectedLink !== null
                Layout.fillWidth: true
                spacing: AppTheme.spacingS

                Text {
                    text: qsTr("Edit attachment")
                    color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

                Text {
                    text: root.selectedLink ? root.selectedLink.label : ""
                    color: AppColors.primaryText; font.pixelSize: AppTypography.bodyMedium.pixelSize; font.bold: true
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    visible: root.selectedLink !== null
                    text: root.selectedLink
                        ? "Slave " + root.selectedLink.slaveId + " · Addr " + root.selectedLink.address
                        : ""
                    color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.labelMedium.pixelSize
                }

                ColumnLayout {
                    visible: root.selectedLink && root.selectedLink.ioType === "DI"
                    Layout.fillWidth: true; spacing: 8
                    Text { text: qsTr("Status code:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    ComboBox {
                        id: editDiTypeCombo
                        Layout.fillWidth: true
                        model: ["00 — Monitoring", "01 — Calibrating", "02 — Error", "03 — Maintenance"]
                    }
                }

                ColumnLayout {
                    visible: root.selectedLink && root.selectedLink.ioType === "DO"
                    Layout.fillWidth: true; spacing: 8
                    Text { text: qsTr("Alarm triggers:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    RowLayout {
                        Layout.fillWidth: true
                        CheckBox {
                            id: editDoTrigMax
                            text: qsTr("Trigger on Max")
                        }
                        CheckBox {
                            id: editDoTrigMin
                            text: qsTr("Trigger on Min")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppButton {
                        text: qsTr("Update")
                        kind: AppButton.Primary
                        Layout.fillWidth: true
                        onClicked: {
                            if (!root.selectedLink) return
                            const linkId = root.selectedLink.id
                            root._pendingSelectId = linkId
                            if (root.selectedLink.ioType === "DI") {
                                root.updateLinkDiTypeRequested(
                                    linkId,
                                    root.diTypeCodeFromComboText(editDiTypeCombo.currentText))
                            } else if (root.selectedLink.ioType === "DO") {
                                root.updateLinkDoTriggersRequested(
                                    linkId,
                                    editDoTrigMax.checked,
                                    editDoTrigMin.checked)
                            }
                        }
                    }

                    AppButton {
                        text: qsTr("Detach")
                        kind: AppButton.Neutral
                        fillColor: AppColors.error
                        Layout.fillWidth: true
                        onClicked: root.deleteSelectedDio()
                    }
                }
            }

            ColumnLayout {
                visible: root.selectedLink === null
                Layout.fillWidth: true
                spacing: AppTheme.spacingSM

                TabBar {
                    id: attachTypeBar
                    Layout.fillWidth: true
                    background: Rectangle { color: "transparent" }
                    ThemedTabButton { text: qsTr("DI"); width: implicitWidth + 30 }
                    ThemedTabButton { text: qsTr("DO"); width: implicitWidth + 30 }
                }

                ColumnLayout {
                    visible: attachTypeBar.currentIndex === 0
                    Layout.fillWidth: true; spacing: AppTheme.spacingS

                    ColumnLayout {
                        visible: root.diSensors.length === 0
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            text: qsTr("No Digital Input sensors configured.")
                            color: AppColors.textFaint; font.pixelSize: AppTypography.bodySmall.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Text {
                            text: qsTr("Go to the Sensors tab and add a sensor with register type Discrete Inputs.")
                            color: AppColors.textFaint; font.pixelSize: AppTypography.labelMedium.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        visible: root.diSensors.length > 0
                        Layout.fillWidth: true; spacing: 8

                        Text { text: qsTr("DI sensor:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                        ComboBox {
                            id: diSensorCombo
                            Layout.fillWidth: true
                            model: root.diSensors.map(function(s) { return root.sensorOptionLabel(s) })
                        }

                        Text { text: qsTr("Status code:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                        ComboBox {
                            id: diTypeCombo
                            Layout.fillWidth: true
                            model: ["00 — Monitoring", "01 — Calibrating", "02 — Error", "03 — Maintenance"]
                        }

                        AppButton {
                            text: qsTr("Attach DI")
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
                    Layout.fillWidth: true; spacing: AppTheme.spacingS

                    ColumnLayout {
                        visible: root.doSensors.length === 0
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            text: qsTr("No Digital Output sensors available.")
                            color: AppColors.textFaint; font.pixelSize: AppTypography.bodySmall.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                        Text {
                            text: qsTr("Add a Coils sensor in the Sensors tab, or all DOs are linked to other analogs.")
                            color: AppColors.textFaint; font.pixelSize: AppTypography.labelMedium.pixelSize
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        visible: root.doSensors.length > 0
                        Layout.fillWidth: true; spacing: 8

                        Text { text: qsTr("DO sensor:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                        ComboBox {
                            id: doSensorCombo
                            Layout.fillWidth: true
                            model: root.doSensors.map(function(s) { return root.sensorOptionLabel(s) })
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            CheckBox { id: doTrigMax; text: qsTr("Trigger on Max"); checked: true }
                            CheckBox { id: doTrigMin; text: qsTr("Trigger on Min"); checked: true }
                        }

                        AppButton {
                            text: qsTr("Attach DO")
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
                    text: qsTr("Attached sensors")
                    color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: dioRepeater.count > 0 ? dioRepeater.count + "" : ""
                    color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodySmall.pixelSize
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

            ListView {
                id: dioListView
                smooth: false
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: dioRepeater.model
                currentIndex: -1
                onCurrentIndexChanged: {
                    root.syncEditPanelFromSelection()
                    if (_pendingSelectId >= 0 && model) {
                        // Model vừa được thay — IndexChange này là reset;
                        // khôi phục đã được xử lý ở SettingsView._refreshLinks
                    }
                }

                delegate: Rectangle {
                    id: linkRow
                    required property int index
                    required property var modelData

                    width: ListView.view.width
                    height: 48
                    radius: AppTheme.radiusTiny
                    // Tap-to-select highlight (pattern từ SettingsSensorsTab)
                    color: ListView.view.currentIndex === linkRow.index
                           ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                           : (linkRow.modelData.ioType === "DO" ? IoColors.doTint : IoColors.diTint)

                    // Left accent bar marks the selected row clearly
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        visible: ListView.view.currentIndex === linkRow.index
                        color: AppColors.primaryColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        // Để delegate nhận click ngay cả khi Repeater model là JS array
                        // (ListView sẽ tự highlight currentIndex mà không cần model owned)
                        onClicked: {
                            ListView.view.currentIndex = (ListView.view.currentIndex === linkRow.index) ? -1 : linkRow.index
                            root._pendingSelectId = -1
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: AppTheme.spacingSM

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: AppTheme.radiusTiny
                            color: linkRow.modelData.ioType === "DO" ? AppColors.error : AppColors.success
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
                            color: AppColors.primaryText
                            font.pixelSize: AppTypography.titleSmall.pixelSize
                            Layout.fillWidth: true
                            Layout.minimumWidth: 60
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            visible: linkRow.modelData.ioType === "DI"
                            text: root.diTypeName(linkRow.modelData.diType)
                            color: AppColors.onSurfaceVariant
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
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
                            color: AppColors.onSurfaceVariant
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.preferredWidth: implicitWidth
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: qsTr("Slave ") + linkRow.modelData.slaveId + " · Addr " + linkRow.modelData.address
                            color: AppColors.onSurfaceVariant
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.preferredWidth: implicitWidth
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                Text {
                    visible: dioListView.count === 0
                    anchors.centerIn: parent
                    width: parent.width - 20
                    text: qsTr("No digital sensors attached.\nSelect DI or DO on the left to attach.")
                    color: AppColors.textFaint; font.pixelSize: AppTypography.bodyMedium.pixelSize
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
