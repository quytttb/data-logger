pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    property bool configChanged: false

    function reloadRows() {
        rowModel.clear()
        let rows = SensorListModel.transmissionRows()
        for (let i = 0; i < rows.length; ++i)
            rowModel.append(rows[i])
    }

    function buildSavePayload() {
        let out = []
        for (let i = 0; i < rowModel.count; ++i) {
            let row = rowModel.get(i)
            out.push({
                sensorId: row.sensorId,
                sensorSymbol: row.sensorSymbol,
                transmitEnabled: row.transmitEnabled
            })
        }
        return out
    }

    function selectedSensorIds() {
        let ids = []
        for (let i = 0; i < rowModel.count; ++i) {
            let row = rowModel.get(i)
            if (row.transmitEnabled)
                ids.push(row.sensorId)
        }
        return ids
    }

    Component.onCompleted: reloadRows()

    Connections {
        target: SensorListModel
        function onModelReset() { root.reloadRows() }
    }

    Connections {
        target: SettingsController
        function onConfigLoaded() {
            autoAddSwitch.checked = SettingsController.autoAddTransmit
        }
    }

    ListModel { id: rowModel }

    Rectangle {
        anchors.fill: parent
        color: AppColors.surfaceContainerLow
        radius: AppTheme.cardRadius
        border.color: AppColors.outlineVariant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: AppTheme.spacingM

            Text {
                text: qsTr("Thông số truyền")
                color: AppColors.accentColor
                font.bold: true
                font.pixelSize: AppTypography.titleSmall.pixelSize
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingM

                Text {
                    text: qsTr("Tự động thêm cảm biến mới")
                    color: AppColors.onSurfaceVariant
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                }
                Switch {
                    id: autoAddSwitch
                    checked: SettingsController ? SettingsController.autoAddTransmit : true
                    onToggled: {
                        SettingsController.autoAddTransmit = checked
                        root.configChanged = true
                    }
                }
                Item { Layout.fillWidth: true }

                AppButton {
                    text: qsTr("Chọn tất cả")
                    kind: AppButton.Neutral
                    onClicked: {
                        for (let i = 0; i < rowModel.count; ++i)
                            rowModel.setProperty(i, "transmitEnabled", true)
                        root.configChanged = true
                    }
                }
                AppButton {
                    text: qsTr("Bỏ chọn tất cả")
                    kind: AppButton.Neutral
                    onClicked: {
                        for (let i = 0; i < rowModel.count; ++i)
                            rowModel.setProperty(i, "transmitEnabled", false)
                        root.configChanged = true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: AppColors.surfaceContainerHigh
                radius: AppTheme.radiusTiny

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: AppTheme.spacingS

                    Text { text: qsTr("STT"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 36 }
                    Text { text: qsTr("Tên cảm biến"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 160 }
                    Text { text: qsTr("Ký hiệu cảm biến"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.fillWidth: true }
                    Text { text: qsTr("Truyền"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignHCenter }
                }
            }

            ListView {
                id: txList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: rowModel
                spacing: 6

                delegate: Rectangle {
                    id: delegateRoot
                    required property int index
                    required property int stt
                    required property int sensorId
                    required property string name
                    required property string sensorSymbol
                    required property bool transmitEnabled

                    // qmllint disable unqualified
                    width: txList.width
                    height: 44
                    color: delegateRoot.index % 2 === 0 ? AppColors.surfaceContainerLow : AppColors.surfaceContainerHigh
                    radius: AppTheme.radiusTiny

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: AppTheme.spacingS

                        Text {
                            text: String(delegateRoot.stt)
                            color: AppColors.onSurfaceVariant
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.preferredWidth: 36
                        }

                        Text {
                            text: delegateRoot.name
                            color: AppColors.onSurfaceVariant
                            font.pixelSize: AppTypography.bodyMedium.pixelSize
                            Layout.preferredWidth: 160
                            elide: Text.ElideRight
                        }

                        ComboBox {
                            Layout.fillWidth: true
                            editable: true
                            model: SensorSymbols.symbols
                            Component.onCompleted: {
                                let symIdx = find(delegateRoot.sensorSymbol || "")
                                if (symIdx >= 0)
                                    currentIndex = symIdx
                                else
                                    editText = delegateRoot.sensorSymbol || ""
                            }
                            onEditTextChanged: {
                                rowModel.setProperty(delegateRoot.index, "sensorSymbol", editText)
                                root.configChanged = true
                            }
                            onActivated: {
                                rowModel.setProperty(delegateRoot.index, "sensorSymbol", currentText)
                                root.configChanged = true
                            }
                        }

                        CheckBox {
                            checked: delegateRoot.transmitEnabled
                            Layout.preferredWidth: 56
                            onToggled: {
                                rowModel.setProperty(delegateRoot.index, "transmitEnabled", checked)
                                root.configChanged = true
                            }
                        }
                    }
                    // qmllint enable unqualified
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.spacingM
                Item { Layout.fillWidth: true }

                AppButton {
                    text: qsTr("LƯU")
                    fillColor: AppColors.success
                    onClicked: {
                        SensorListModel.saveTransmission(root.buildSavePayload())
                        if (root.configChanged)
                            SettingsController.saveConfig()
                        root.configChanged = false
                    }
                }

                AppButton {
                    text: qsTr("XÓA")
                    fillColor: AppColors.error
                    onClicked: {
                        var ids = root.selectedSensorIds()
                        if (ids.length === 0)
                            return
                        SensorListModel.removeFromTransmission(ids)
                        root.configChanged = false
                    }
                }
            }
        }
    }
}
