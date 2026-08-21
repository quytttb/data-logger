import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

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
        color: Theme.bgPanel
        radius: Theme.radiusCard
        border.color: Theme.borderDefault
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: Theme.spacingM

            Text {
                text: "Thông số truyền"
                color: Theme.accentText
                font.bold: true
                font.pixelSize: AppTypography.titleSmall.pixelSize
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Text {
                    text: "Tự động thêm cảm biến mới"
                    color: Theme.textLabel
                    font.pixelSize: Theme.fontLabelSize
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
                    text: "Chọn tất cả"
                    variant: "tonal"
                    onClicked: {
                        for (let i = 0; i < rowModel.count; ++i)
                            rowModel.setProperty(i, "transmitEnabled", true)
                        root.configChanged = true
                    }
                }
                AppButton {
                    text: "Bỏ chọn tất cả"
                    variant: "tonal"
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
                color: Theme.bgSeparator
                radius: Theme.radiusTiny

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: Theme.spacingS

                    Text { text: "STT"; color: Theme.accentText; font.bold: true; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 36 }
                    Text { text: "Tên cảm biến"; color: Theme.accentText; font.bold: true; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 160 }
                    Text { text: "Ký hiệu cảm biến"; color: Theme.accentText; font.bold: true; font.pixelSize: Theme.fontLabelSize; Layout.fillWidth: true }
                    Text { text: "Truyền"; color: Theme.accentText; font.bold: true; font.pixelSize: Theme.fontLabelSize; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignHCenter }
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
                    color: delegateRoot.index % 2 === 0 ? Theme.bgPanel : Theme.bgSeparator
                    radius: Theme.radiusTiny

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: Theme.spacingS

                        Text {
                            text: String(delegateRoot.stt)
                            color: Theme.textLabel
                            font.pixelSize: Theme.fontLabelSize
                            Layout.preferredWidth: 36
                        }

                        Text {
                            text: delegateRoot.name
                            color: Theme.textLabel
                            font.pixelSize: Theme.fontLabelSize
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
                spacing: Theme.spacingM
                Item { Layout.fillWidth: true }

                AppButton {
                    text: "LƯU"
                    accent: Theme.btnStart
                    onClicked: {
                        SensorListModel.saveTransmission(root.buildSavePayload())
                        if (root.configChanged)
                            SettingsController.saveConfig()
                        root.configChanged = false
                    }
                }

                AppButton {
                    text: "XÓA"
                    accent: Theme.btnStop
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
