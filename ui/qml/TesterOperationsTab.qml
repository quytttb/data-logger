import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight

    property alias regTypeCombo: regTypeCombo
    property alias dataTypeCombo: dataTypeCombo
    property alias scanStartSpin: scanStartSpin
    property alias scanEndSpin: scanEndSpin
    property alias scanCountSpin: scanCountSpin

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        GridLayout {
            Layout.fillWidth: true
            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            Label {
                text: qsTr("Register type:")
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: regTypeCombo
                Layout.fillWidth: true
                model: ["Holding Register", "Input Register", "Coil", "Discrete Input"]
                currentIndex: 1
            }

            Label {
                text: qsTr("Data type:")
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: dataTypeCombo
                Layout.fillWidth: true
                model: ["Decimal", "Float", "Swapped Float"]
                currentIndex: 0
            }

            Label {
                text: qsTr("Start address:")
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: scanStartSpin
                from: 0
                to: 65535
                value: 0
                editable: true
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("End address:")
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: scanEndSpin
                from: 0
                to: 65535
                value: 100
                editable: true
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("Registers per read:")
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: scanCountSpin
                from: 1
                to: 125
                value: 8
                Layout.fillWidth: true
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Number of consecutive registers read at each address (1–125).")
            }
        }
    }
}
