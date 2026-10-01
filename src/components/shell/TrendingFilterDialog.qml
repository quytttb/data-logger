pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

// Dialog lọc Trending (kit Dialog, theo mẫu MessageDetailDialog):
// chọn cảm biến + khoảng thời gian lịch sử (số + đơn vị phút/giờ/ngày).
Dialog {
    id: root

    // TrendingTaskBar nguồn selectedIds/setChecked/selectAll/allIds.
    // Để var (dynamic) — qmllint không resolve member của Item, còn type
    // cụ thể gây incompatible-type do tham chiếu vòng cùng module.
    property var taskBar: null

    title: qsTr("Trending filter")
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    standardButtons: Dialog.NoButton

    width: parent
        ? Math.min(parent.width - 48, AppTheme.dialogMaxWidth)
        : AppTheme.dialogMaxWidth
    anchors.centerIn: parent

    Material.roundedScale: Material.ExtraLargeScale

    background: Rectangle {
        color: AppColors.surfaceContainerHigh
        radius: AppTheme.cardRadius
        border.width: 1
        border.color: AppColors.elevatedBorder
    }

    function applyHistory() {
        if (!root.taskBar)
            return
        const now = new Date()
        const mult = unitBox.currentIndex === 0 ? 60000
                   : (unitBox.currentIndex === 1 ? 3600000 : 86400000)
        const from = new Date(now.getTime() - amountSpin.value * mult)
        // selectedIds rỗng = tất cả — query cần id cụ thể.
        const ids = root.taskBar.selectedIds.length === 0
                    ? root.taskBar.allIds()
                    : root.taskBar.selectedIds.slice()
        TrendingHistoryViewModel.query(ids, from, now)
        root.close()
    }

    function backToLive() {
        TrendingHistoryViewModel.clear()
        root.close()
    }

    contentItem: RowLayout {
        spacing: 0

        // ════════════════════════════════════════════════════════════════
        // Cột trái: Time-range controls + ghi chú
        // ════════════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.preferredWidth: 280
            Layout.minimumWidth: 240
            Layout.fillHeight: true
            Layout.rightMargin: AppTheme.spacingM
            spacing: AppTheme.spacingSM

            Text {
                text: qsTr("Time range")
                color: AppColors.primaryText
                font.pixelSize: AppTypography.titleSmall.pixelSize
                font.bold: true
            }

            Text {
                text: qsTr("Show last:")
                color: AppColors.onSurfaceVariant
                font.pixelSize: AppTypography.bodyMedium.pixelSize
            }

            SpinBox {
                id: amountSpin
                from: 1
                to: 365
                value: 1
                editable: true
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 365 }
                Layout.fillWidth: true
                Layout.preferredHeight: 48
            }

            ComboBox {
                id: unitBox
                model: [qsTr("Minutes"), qsTr("Hours"), qsTr("Days")]
                currentIndex: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 48
            }

            // Spacer đẩy ghi chú xuống đáy cột trái
            Item { Layout.fillHeight: true }

            Text {
                text: qsTr("Uncheck all = show all.\nAt least one stays on.")
                color: AppColors.onSurfaceVariant
                font.pixelSize: AppTypography.bodySmall.pixelSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // ── Divider dọc ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: AppColors.outlineVariant
        }

        // ════════════════════════════════════════════════════════════════
        // Cột phải: Sensor checkboxes
        // ════════════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: AppTheme.spacingM
            spacing: AppTheme.spacingS

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Sensors")
                    color: AppColors.primaryText
                    font.pixelSize: AppTypography.titleSmall.pixelSize
                    font.bold: true
                    Layout.fillWidth: true
                }
                AppButton {
                    kind: AppButton.Secondary
                    text: qsTr("All")
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.taskBar ? root.taskBar.selectAll() : undefined
                }
            }

            ScrollView {
                id: sensorScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 48
                clip: true

                ColumnLayout {
                    id: sensorList
                    width: sensorScroll.availableWidth
                    spacing: 2

                    Repeater {
                        model: MonitorController.analogSensors

                        delegate: RowLayout {
                            id: checkRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            spacing: 8
                            required property var modelData

                            Rectangle {
                                implicitWidth: 12
                                implicitHeight: 12
                                radius: width / 2
                                color: checkRow.modelData.color
                                Layout.alignment: Qt.AlignVCenter
                            }

                            CheckBox {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: checkRow.modelData.unit && checkRow.modelData.unit.length > 0
                                      ? (checkRow.modelData.name + " (" + checkRow.modelData.unit + ")")
                                      : checkRow.modelData.name
                                font.pixelSize: AppTypography.bodyMedium.pixelSize
                                checked: !root.taskBar || root.taskBar.selectedIds.length === 0
                                         || root.taskBar.selectedIds.indexOf(checkRow.modelData.id) >= 0
                                onToggled: {
                                    if (root.taskBar)
                                        root.taskBar.setChecked(checkRow.modelData.id, checked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    footer: DialogButtonBox {
        spacing: 8

        AppButton {
            kind: AppButton.Text
            text: qsTr("Live")
            DialogButtonBox.buttonRole: DialogButtonBox.ResetRole
            onClicked: root.backToLive()
        }

        AppButton {
            kind: AppButton.Tonal
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            onClicked: root.close()
        }

        AppButton {
            kind: AppButton.Primary
            text: qsTr("Apply")
            enabled: !TrendingHistoryViewModel.loading
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            onClicked: root.applyHistory()
        }
    }
}
