pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

// Hiệu chuẩn tuyến tính 2..N điểm cho cảm biến analog.
//
// Mở từ thẻ cảm biến ở màn Monitor (người có Permission::Calibrate). Việc tính
// a/b và ghi DB nằm ở CalibrationController — QML chỉ thu thập điểm và hiển thị
// kết quả xem trước.
Rectangle {
    id: root

    anchors.fill: parent
    z: 100
    visible: false
    readonly property color overlayColor: "#000000"
    color: AppColors.withAlpha(overlayColor, 0.55)

    property int sensorId: 0
    property string sensorName: ""
    property string sensorUnit: ""
    property var preview: ({ ok: false, error: "", residuals: [] })
    property var currentInfo: ({})
    property var historyRows: []
    property string errorText: ""

    readonly property var fitted: (preview && preview.ok) ? preview : null

    function formatTime(iso) {
        if (!iso)
            return "—"
        const d = new Date(iso)
        if (isNaN(d.getTime()))
            return iso
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function num(value) {
        if (value === undefined || value === null || value === "")
            return "—"
        const n = Number(value)
        return isFinite(n) ? String(Number(n.toPrecision(15))) : "—"
    }

    function open(id, name, unit) {
        sensorId = id
        sensorName = name
        sensorUnit = unit
        errorText = ""
        noteField.text = ""
        visible = true
        reload()
    }

    function closePanel() {
        visible = false
        confirmPopup.close()
        noteField.text = ""
        pointsModel.clear()
        preview = ({ ok: false, error: "", residuals: [] })
        errorText = ""
    }

    function appendPoint(raw, reference) {
        pointsModel.append({
            rawText: (raw === undefined || raw === null) ? "" : String(raw),
            referenceText: (reference === undefined || reference === null) ? "" : String(reference)
        })
    }

    function reload() {
        currentInfo = CalibrationController.current(sensorId)

        const sessions = CalibrationController.history(sensorId)
        const rows = []
        for (let i = 0; i < sessions.length; ++i) {
            const s = sessions[i]
            let label = formatTime(s.createdAt) + " · " + s.pointCount + " pts"
                        + " · a=" + num(s.a) + " b=" + num(s.b)
            if (s.r2 !== undefined && s.r2 !== null)
                label += " · R²=" + num(s.r2)
            rows.push({ id: s.id, label: label })
        }
        historyRows = rows
        historyCombo.currentIndex = -1

        pointsModel.clear()
        // Lịch sử có thể không còn tương ứng hệ số hiện hành sau khi nhập tay.
        // Không tự nạp điểm cũ: người vận hành chủ động chọn một phiên.
        appendPoint("", "")
        appendPoint("", "")
        updatePreview()
    }

    function loadSession(sessionId) {
        const points = CalibrationController.sessionPoints(sessionId)
        if (points.length < 2)
            return
        pointsModel.clear()
        for (let i = 0; i < points.length; ++i)
            appendPoint(points[i].raw, points[i].reference)
        updatePreview()
    }

    function updatePoint(index, field, value) {
        const row = pointsModel.get(index)
        if (!row || row[field] === value)
            return
        pointsModel.setProperty(index, field, value)
    }

    function collectPoints() {
        const out = []
        for (let i = 0; i < pointsModel.count; ++i) {
            const row = pointsModel.get(i)
            const raw = String(row.rawText === undefined ? "" : row.rawText).trim()
            const reference = String(row.referenceText === undefined ? "" : row.referenceText).trim()
            if (raw === "" && reference === "")
                continue
            out.push({ raw: raw, reference: reference })
        }
        return out
    }

    function updatePreview() {
        errorText = ""
        preview = CalibrationController.fit(collectPoints())
    }

    function residualForRow(index) {
        if (!root.fitted)
            return ""
        let fittedIndex = 0
        for (let i = 0; i <= index; ++i) {
            const row = pointsModel.get(i)
            if (!row)
                return ""
            if (String(row.rawText).trim() === "" && String(row.referenceText).trim() === "") {
                if (i === index)
                    return ""
                continue
            }
            if (i === index)
                return root.num(root.fitted.residuals[fittedIndex])
            ++fittedIndex
        }
        return ""
    }

    function doApply() {
        const result = CalibrationController.apply(sensorId, collectPoints(), noteField.text)
        if (!result || !result.ok) {
            errorText = (result && result.error) ? result.error : qsTr("Calibration failed.")
            return
        }
        closePanel()
    }

    function confirmApply() {
        if (!root.fitted || root.fitted.pointCount < 2)
            return
        confirmPopup.showConfirm(
            qsTr("Apply calibration"),
            qsTr("Save %1 points and update the coefficient of \"%2\" now?\n"
                 + "a = %3, b = %4")
                .arg(root.fitted.pointCount).arg(root.sensorName)
                .arg(num(root.fitted.a)).arg(num(root.fitted.b)),
            function() { root.doApply() },
            qsTr("Apply"),
            AppColors.success)
    }

    ListModel { id: pointsModel }

    // Không để thao tác chạm xuyên qua vùng nền của hộp hiệu chuẩn.
    MouseArea { anchors.fill: parent }

    Connections {
        target: AuthService
        function onSessionChanged() {
            if (!AuthService.canCalibrate && root.visible)
                root.closePanel()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(root.width - 32, 920)
        height: Math.min(root.height - 16, 520)
        radius: AppTheme.cardRadius
        color: AppColors.surfaceContainerLow
        border.color: AppColors.elevatedBorder
        border.width: 1
        clip: true

        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, panelContent.implicitHeight + 2 * AppTheme.spacingSM)
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: panelContent
            x: AppTheme.spacingSM
            y: AppTheme.spacingSM
            width: parent.width - 2 * AppTheme.spacingSM
            height: Math.max(parent.height - 2 * AppTheme.spacingSM, implicitHeight)
            spacing: AppTheme.spacingS

            // ── Header ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingS

                Text {
                    text: qsTr("Calibration — %1").arg(root.sensorName)
                    color: AppColors.primaryText
                    font: AppTypography.titleMedium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.currentInfo && root.currentInfo.ok === true
                    text: root.currentInfo.hasCoefficient
                          ? qsTr("Current: a=%1  b=%2")
                                .arg(root.num(root.currentInfo.a)).arg(root.num(root.currentInfo.b))
                          : qsTr("Current: raw or Advanced JSON")
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodySmall
                }

                AppButton {
                    text: qsTr("Close")
                    kind: AppButton.Neutral
                    onClicked: root.closePanel()
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

            // ── Points ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingS

                Text {
                    text: qsTr("Raw value")
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodySmall
                    Layout.preferredWidth: 150
                }
                Text {
                    text: qsTr("Reference (%1)").arg(root.sensorUnit)
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodySmall
                    Layout.preferredWidth: 150
                }
                Text {
                    text: qsTr("Error")
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodySmall
                    Layout.fillWidth: true
                }
                Item { Layout.preferredWidth: 88 }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120
                Layout.preferredHeight: 160
                clip: true
                contentHeight: pointsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: pointsColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: pointsModel

                        delegate: RowLayout {
                            id: pointRow
                            required property int index
                            required property string rawText
                            required property string referenceText

                            width: pointsColumn.width
                            spacing: AppTheme.spacingS

                            TextField {
                                Layout.preferredWidth: 150
                                text: pointRow.rawText
                                placeholderText: qsTr("Raw")
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                onTextChanged: {
                                    root.updatePoint(pointRow.index, "rawText", text)
                                    root.updatePreview()
                                }
                            }

                            TextField {
                                Layout.preferredWidth: 150
                                text: pointRow.referenceText
                                placeholderText: qsTr("Reference")
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                onTextChanged: {
                                    root.updatePoint(pointRow.index, "referenceText", text)
                                    root.updatePreview()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.residualForRow(pointRow.index)
                                color: AppColors.tableCellMuted
                                font: AppTypography.bodySmall
                                elide: Text.ElideRight
                            }

                            AppButton {
                                Layout.preferredWidth: 80
                                text: qsTr("Remove")
                                kind: AppButton.Neutral
                                enabled: pointsModel.count > 2
                                onClicked: {
                                    pointsModel.remove(pointRow.index)
                                    root.updatePreview()
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingS

                AppButton {
                    text: qsTr("Add point")
                    kind: AppButton.Secondary
                    onClicked: {
                        root.appendPoint("", "")
                        root.updatePreview()
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.preview && !root.preview.ok && root.preview.error !== ""
                    text: root.preview ? root.preview.error : ""
                    color: AppColors.error
                    font: AppTypography.bodySmall
                    elide: Text.ElideRight
                    Layout.maximumWidth: 420
                }
            }

            // ── Preview ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: AppTheme.radiusTiny
                color: AppColors.surfaceContainer
                border.color: root.errorText !== "" ? AppColors.error : AppColors.elevatedBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: AppTheme.spacingS
                    spacing: AppTheme.spacingM

                    Text {
                        text: root.errorText !== "" ? root.errorText : root.fitted
                              ? qsTr("a = %1    b = %2    R² = %3    max error = %4")
                                    .arg(root.num(root.fitted.a))
                                    .arg(root.num(root.fitted.b))
                                    .arg(root.fitted.r2 !== undefined && root.fitted.r2 !== null
                                         ? root.num(root.fitted.r2) : "—")
                                    .arg(root.num(root.fitted.maxResidual))
                              : qsTr("Enter at least 2 points with different raw values.")
                        color: root.errorText === "" ? AppColors.primaryText : AppColors.error
                        font: AppTypography.bodyMedium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                text: qsTr("R² indicates fit only, not certification. History may not match the current coefficients.")
                color: AppColors.onSurfaceVariant
                font: AppTypography.bodySmall
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // ── Note + history ───────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingS

                TextField {
                    id: noteField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Note / reference standard (optional)")
                }

                Text {
                    text: qsTr("History")
                    color: AppColors.onSurfaceVariant
                    font: AppTypography.bodySmall
                }

                ComboBox {
                    id: historyCombo
                    Layout.preferredWidth: 320
                    textRole: "label"
                    currentIndex: -1
                    model: root.historyRows
                    onActivated: {
                        if (currentIndex >= 0 && currentIndex < root.historyRows.length)
                            root.loadSession(root.historyRows[currentIndex].id)
                    }
                }

                AppButton {
                    text: qsTr("Apply calibration")
                    font.bold: true
                    enabled: root.fitted !== null && AuthService.canCalibrate
                    onClicked: root.confirmApply()
                }
            }
        }
        }
    }

    MessagePopup {
        id: confirmPopup
        parent: Overlay.overlay
    }
}
