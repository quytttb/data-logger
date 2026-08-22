pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme

Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight

    property alias regTypeCombo: regTypeComboItem
    property alias dataTypeCombo: dataTypeCombo
    property alias dataFormatCombo: dataFormatCombo
    property alias scanStartSpin: scanStartSpin
    property alias scanEndSpin: scanEndSpin
    property alias scanCountSpin: scanCountSpin
    property alias slaveSpin: slaveSpin
    property alias writeAddrSpin: writeAddrSpin
    property alias writeValSpin: writeValSpin
    property bool isReadMode: true

    readonly property bool isBooleanType: regTypeComboItem.currentText === "Coils"
                                       || regTypeComboItem.currentText === "Discrete Inputs"

    ColumnLayout {
        id: col
        width: root.width
        spacing: AppTheme.spacingS

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Label {
                text: qsTr("Slave ID:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: slaveSpin
                from: 1; to: 247; value: 1
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("Register type:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: regTypeComboItem
                Layout.fillWidth: true
                model: root.isReadMode ? ["Holding Registers", "Input Registers", "Coils", "Discrete Inputs"]
                                  : ["Holding Registers", "Coils"]
                currentIndex: 1
            }

            Label {
                text: qsTr("Data type:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !root.isBooleanType
            }
            ComboBox {
                id: dataTypeCombo
                Layout.fillWidth: true
                model: AppDefaults.dataTypes
                currentIndex: 1
                visible: !root.isBooleanType
            }

            Label {
                text: qsTr("Endian format:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !root.isBooleanType
            }
            ComboBox {
                id: dataFormatCombo
                Layout.fillWidth: true
                model: AppDefaults.byteOrders
                currentIndex: 0
                visible: !root.isBooleanType
            }

            Label {
                text: qsTr("Start address:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: root.isReadMode
            }
            SpinBox {
                id: scanStartSpin
                from: 0; to: 65535; value: 0
                editable: true
                Layout.fillWidth: true
                visible: root.isReadMode
            }

            Label {
                text: qsTr("End address:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: root.isReadMode
            }
            SpinBox {
                id: scanEndSpin
                from: 0; to: 65535; value: 100
                editable: true
                Layout.fillWidth: true
                visible: root.isReadMode
            }

            Label {
                text: qsTr("Registers per read:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: root.isReadMode
            }
            SpinBox {
                id: scanCountSpin
                from: 1; to: 125; value: 8
                Layout.fillWidth: true
                visible: root.isReadMode
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Number of consecutive registers read at each address (1–125).")
            }

            Label {
                text: qsTr("Write address:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !root.isReadMode
            }
            SpinBox {
                id: writeAddrSpin
                from: 0; to: 65535; value: 0
                editable: true
                Layout.fillWidth: true
                visible: !root.isReadMode
            }

            Label {
                text: qsTr("Write value:")
                color: AppColors.onSurfaceVariant
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !root.isReadMode
            }
            SpinBox {
                id: writeValSpin
                from: -9999999; to: 9999999; value: 1
                editable: true
                Layout.fillWidth: true
                visible: !root.isReadMode
            }
        }
    }
}
