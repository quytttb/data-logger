pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

// Nhật ký thao tác (audit). Chỉ đọc; việc ghi nằm trong transaction của từng
// nghiệp vụ. Chỉ admin (Permission::ViewAudit) thấy tab này.
Rectangle {
    id: root

    color: AppColors.surfaceContainerLow
    radius: AppTheme.cardRadius
    border.color: AppColors.elevatedBorder
    border.width: 1

    property var actionList: []
    property var entityList: []
    property int currentRow: -1

    readonly property var selected: (currentRow >= 0
                                     && currentRow < AuditController.entries.length)
                                    ? AuditController.entries[currentRow] : null

    function formatTime(iso) {
        if (!iso)
            return "—"
        const d = new Date(iso)
        if (isNaN(d.getTime()))
            return iso
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function prettyJson(text) {
        try {
            return JSON.stringify(JSON.parse(text), null, 2)
        } catch (e) {
            return String(text)
        }
    }

    function objectLabel(entry) {
        if (!entry)
            return ""
        if (!entry.entityId)
            return entry.entity
        return entry.entity + " #" + entry.entityId
    }

    function resultText(value) {
        if (value === "ok")
            return qsTr("OK")
        if (value === "denied")
            return qsTr("Denied")
        if (value === "failed")
            return qsTr("Failed")
        return value
    }

    function resultColor(value) {
        if (value === "denied" || value === "failed")
            return AppColors.error
        if (value === "ok")
            return AppColors.success
        return AppColors.tableCellMuted
    }

    function refreshFilters() {
        actionList = AuditController.actionOptions()
        entityList = AuditController.entityOptions()
    }

    function applyFilters() {
        const action = actionCombo.currentIndex > 0
                       ? actionList[actionCombo.currentIndex - 1] : ""
        const entity = entityCombo.currentIndex > 0
                       ? entityList[entityCombo.currentIndex - 1] : ""
        let result = ""
        if (resultCombo.currentIndex === 1)
            result = "ok"
        else if (resultCombo.currentIndex === 2)
            result = "denied"
        else if (resultCombo.currentIndex === 3)
            result = "failed"
        const days = rangeCombo.model[rangeCombo.currentIndex].value
        root.currentRow = -1
        AuditController.setFilters(action, entity, result, days)
    }

    function rebuildRows() {
        const list = AuditController.entries
        const rows = []
        for (let i = 0; i < list.length; ++i) {
            const entry = list[i]
            rows.push([
                formatTime(entry.occurredAt),
                entry.actor,
                entry.action,
                objectLabel(entry),
                resultText(entry.result)
            ])
        }
        // qmllint disable unqualified
        auditTableModel.setHeaders([
            qsTr("Time"), qsTr("User"), qsTr("Action"), qsTr("Object"), qsTr("Result")])
        auditTableModel.setRows(rows)
        // qmllint enable unqualified
    }

    onVisibleChanged: {
        if (visible) {
            currentRow = -1
            refreshFilters()
            AuditController.refresh()
            rebuildRows()
        } else {
            currentRow = -1
        }
    }

    Component.onCompleted: rebuildRows()

    Connections {
        target: AuditController
        function onChanged() {
            root.currentRow = -1
            root.rebuildRows()
        }
    }

    JsonTableModel {
        id: auditTableModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: AppTheme.spacingSM
            Layout.rightMargin: AppTheme.spacingSM
            spacing: AppTheme.spacingS

            ComboBox {
                id: actionCombo
                Layout.preferredWidth: 200
                model: [qsTr("All actions")].concat(root.actionList)
                onActivated: root.applyFilters()
            }

            ComboBox {
                id: entityCombo
                Layout.preferredWidth: 150
                model: [qsTr("All objects")].concat(root.entityList)
                onActivated: root.applyFilters()
            }

            ComboBox {
                id: resultCombo
                Layout.preferredWidth: 120
                model: [qsTr("All results"), qsTr("OK"), qsTr("Denied"), qsTr("Failed")]
                onActivated: root.applyFilters()
            }

            ComboBox {
                id: rangeCombo
                Layout.preferredWidth: 140
                textRole: "label"
                model: [
                    { value: 0,  label: qsTr("All time") },
                    { value: 7,  label: qsTr("Last 7 days") },
                    { value: 30, label: qsTr("Last 30 days") },
                    { value: 90, label: qsTr("Last 90 days") }
                ]
                onActivated: root.applyFilters()
            }

            AppButton {
                text: qsTr("Refresh")
                kind: AppButton.Neutral
                onClicked: {
                    root.refreshFilters()
                    AuditController.refresh()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Tách phân trang khỏi bộ lọc để không tràn chiều ngang kiosk 1024 px.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: AppTheme.spacingSM
            Layout.rightMargin: AppTheme.spacingSM
            spacing: AppTheme.spacingS

            Text {
                text: qsTr("%1 entries").arg(AuditController.total)
                color: AppColors.onSurfaceVariant
                font: AppTypography.bodyMedium
            }

            Item { Layout.fillWidth: true }

            AppButton {
                text: qsTr("Prev")
                kind: AppButton.Neutral
                enabled: AuditController.page > 0
                onClicked: AuditController.previousPage()
            }

            Text {
                text: qsTr("Page %1 / %2").arg(AuditController.page + 1)
                      .arg(AuditController.pageCount)
                color: AppColors.onSurfaceVariant
                font: AppTypography.bodyMedium
            }

            AppButton {
                text: qsTr("Next")
                kind: AppButton.Neutral
                enabled: AuditController.page + 1 < AuditController.pageCount
                onClicked: AuditController.nextPage()
            }
        }

        AppTableView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // qmllint disable unqualified
            model: auditTableModel
            // qmllint enable unqualified
            hasData: AuditController.entries.length > 0
            colWeights: [0.22, 0.20, 0.24, 0.22, 0.12]
            colMinimums: [140, 110, 160, 130, 70]
            headerAlignCenter: function(col) { return col === 4 }
            emptyMessage: qsTr("No audit entries match the filter.")
            emptyIconName: "informationOutline"

            delegate: Rectangle {
                id: cell
                required property int row
                required property int column
                required property var display

                implicitHeight: 42
                color: "transparent"

                TableCellBackground { cellHovered: false }

                Rectangle {
                    anchors.fill: parent
                    color: root.currentRow === cell.row
                           ? AppColors.withAlpha(AppColors.primaryColor, 0.16)
                           : "transparent"

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        visible: root.currentRow === cell.row && cell.column === 0
                        color: AppColors.primaryColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentRow = (root.currentRow === cell.row) ? -1 : cell.row
                }

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: cell.column === 0 ? AppTheme.spacingM : AppTheme.spacingS
                        right: parent.right
                        rightMargin: AppTheme.spacingS
                        verticalCenter: parent.verticalCenter
                    }
                    text: String(cell.display)
                    color: cell.column === 4
                           ? root.resultColor(cell.row >= 0
                                              && cell.row < AuditController.entries.length
                                              ? AuditController.entries[cell.row].result : "")
                           : (cell.column === 2 ? AppColors.primaryText : AppColors.tableCellMuted)
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    font.weight: cell.column === 2 ? Font.DemiBold : Font.Normal
                    horizontalAlignment: cell.column === 4 ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }

        // Chi tiết JSON của dòng đang chọn (whitelist do nơi ghi quyết định).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            Layout.margins: AppTheme.spacingSM
            visible: root.selected !== null
            radius: AppTheme.cardRadius
            color: AppColors.surfaceContainer
            border.color: AppColors.elevatedBorder
            border.width: 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: AppTheme.spacingS
                clip: true

                TextArea {
                    text: root.selected !== null ? root.prettyJson(root.selected.detailJson) : ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    color: AppColors.tableCellMuted
                    font.pixelSize: AppTypography.bodySmall.pixelSize
                    background: Item {}
                }
            }
        }
    }
}
