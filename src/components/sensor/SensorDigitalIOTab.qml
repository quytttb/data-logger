pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

ElevatedPane {
    id: root
    padding: 20
    contentSpacing: 0

    signal attachDiRequested(int diSensorId, string diType)
    signal attachDoRequested(int doSensorId, bool trigMax, bool trigMin)
    signal removeDioRequested(int linkId)
    signal updateLinkDiTypeRequested(int linkId, string diType)
    signal updateLinkDoTriggersRequested(int linkId, bool trigMax, bool trigMin)

    property alias dioRepeaterRef: dioRepeater
    property var diSensors: []
    property var doSensors: []

    function sensorOptionLabel(s) {
        // 2 dòng: dòng 1 = tên sensor, dòng 2 = (Slave; Addr) — tên dài sẽ được
        // popup ComboBox bọc xuống dòng 2 thay vì bị cắt mất phần Slave/Addr.
        return s.name + "\n(Slave " + s.slaveId + "; Addr " + s.address + ")"
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

    // Snapshot table model for the attached-sensors table (AppTableView needs
    // a columnar model; parallel linkIds[] keeps selection by row index).
    JsonTableModel {
        id: dioTableModel
    }
    property var linkIds: []

    readonly property var selectedLink: {
        const m = dioRepeater.model
        if (!m || root.dioListRow < 0 || root.dioListRow >= m.length)
            return null
        return m[root.dioListRow]
    }

    // Selection row index (mirrors ListView.currentIndex semantics).
    property int dioListRow: -1

    // Sticky selection across model refresh — ListView resets currentIndex khi
    // Repeater model thay bằng array mới. Lưu id và khôi phục sau khi gán model.
    property int _pendingSelectId: -1

    property bool hasSelectedDio: selectedLink !== null

    function clearSelection() {
        _pendingSelectId = -1
        root.dioListRow = -1
        root.rebuildTable()
    }

    function restoreSelectionById(linkId) {
        const m = dioRepeater.model
        if (!m || linkId < 0) return
        for (let i = 0; i < m.length; ++i) {
            if (m[i].id === linkId) { root.dioListRow = i; break }
        }
    }

    // Rebuild the table snapshot from the current links array (same array that
    // fish the view). Called on model changes via _refreshLinks in SettingsView.
    function rebuildTable() {
        const m = dioRepeater.model
        const rows = []
        const ids = []
        if (m) {
            for (let i = 0; i < m.length; ++i) {
                const l = m[i]
                rows.push([
                    l.ioType,
                    l.label,
                    (l.ioType === "DI" ? root.diTypeName(l.diType)
                                       : (l.ioType === "DO"
                                          ? ((l.triggerOnMax ? "Max" : "") +
                                             (l.triggerOnMax && l.triggerOnMin ? ", " : "") +
                                             (l.triggerOnMin ? "Min" : ""))
                                          : "")),
                    "Slave " + l.slaveId + " · Addr " + l.address
                ])
                ids.push(l.id)
            }
        }
        root.linkIds = ids
        dioTableModel.setHeaders(["Type", "Sensor", "DI type / Trigger", "Modbus"])
        dioTableModel.setRows(rows)
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
            root.dioListRow = -1
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
        Layout.fillWidth: true
        Layout.fillHeight: true
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
                            // Không custom delegate: popup mặc định tự xuống dòng ở "\n"
                            // (tên dòng 1, Slave/Addr dòng 2). Nút đóng chỉ hiện tên.
                            contentItem: Label {
                                text: diSensorCombo.displayText.split("\n")[0]
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                rightPadding: 28
                            }
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
                            // Không custom delegate: popup mặc định tự xuống dòng ở "\n"
                            // (tên dòng 1, Slave/Addr dòng 2). Nút đóng chỉ hiện tên.
                            contentItem: Label {
                                text: doSensorCombo.displayText.split("\n")[0]
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                rightPadding: 28
                            }
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
            Layout.preferredWidth: 1.8
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

            AppTableView {
                id: dioTable
                Layout.fillWidth: true; Layout.fillHeight: true
                model: dioTableModel
                hasData: dioTableModel.count > 0
                loading: false
                reuseItems: true
                colWeights: [0.12, 0.38, 0.25, 0.25]
                colMinimums: [50, 120, 90, 110]
                headerAlignCenter: function(col) { return col === 0 }
                emptyMessage: qsTr("No digital sensors attached.\nSelect DI or DO on the left to attach.")

                delegate: Rectangle {
                    id: linkCell
                    required property int row
                    required property int column
                    required property var display

                    implicitHeight: 44
                    color: "transparent"

                    TableCellBackground { cellHovered: false }

                    Rectangle {
                        anchors.fill: parent
                        color: root.dioListRow === linkCell.row
                               ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                               : "transparent"
                        // Left accent bar đánh dấu dòng đang chọn
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3
                            visible: root.dioListRow === linkCell.row
                            color: AppColors.primaryColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Tap lại dòng đang chọn => bỏ chọn (toggle)
                            root.dioListRow = (root.dioListRow === linkCell.row) ? -1 : linkCell.row
                            root._pendingSelectId = -1
                        }
                    }

                    Rectangle {
                        visible: linkCell.column === 0
                        anchors.centerIn: parent
                        width: 34; height: 22; radius: AppTheme.radiusTiny
                        color: (linkCell.display === "DO") ? AppColors.error : AppColors.success
                        Text {
                            anchors.centerIn: parent
                            text: linkCell.display
                            color: AppColors.onPrimary
                            font.bold: true
                            font.pixelSize: AppTypography.labelSmall.pixelSize
                        }
                    }

                    Text {
                        visible: linkCell.column !== 0
                        anchors {
                            left: parent.left
                            leftMargin: linkCell.column === 1 ? AppTheme.spacingS : 4
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        text: String(linkCell.display)
                        color: linkCell.column === 1 ? AppColors.primaryText : AppColors.tableCellMuted
                        font.pixelSize: AppTypography.bodyMedium.pixelSize
                        font.bold: linkCell.column === 1
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Repeater {
        id: dioRepeater
        delegate: Item { visible: false }
        // Khi SettingsView gán model mới (get_analog_links), rebuild bảng snapshot.
        onModelChanged: root.rebuildTable()
    }
}
