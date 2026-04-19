import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight

    property alias portCombo: portCombo
    property alias baudCombo: baudCombo
    property alias parityCombo: parityCombo
    property alias dataBitsSpin: dataBitsSpin
    property alias stopBitsCombo: stopBitsCombo
    property alias slaveSpin: slaveSpin

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
                text: "Port:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                ComboBox {
                    id: portCombo
                    Layout.fillWidth: true
                    model: testerController.availablePorts
                    editable: true
                    Component.onCompleted: { if (count > 0) currentIndex = 0 }
                }
                ToolButton {
                    icon.source: "../../../assets/icons/refresh.svg"
                    icon.color: Theme.accentText
                    icon.width: 18
                    icon.height: 18
                    onClicked: testerController.refresh_ports()
                    ToolTip.visible: hovered
                    ToolTip.text: "Refresh port list"
                }
            }

            Label {
                text: "Baud rate:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: baudCombo
                Layout.fillWidth: true
                model: ["4800", "9600", "19200", "38400", "115200"]
                currentIndex: 1
            }

            Label {
                text: "Parity:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: parityCombo
                Layout.fillWidth: true
                model: ["N", "E", "O"]
                currentIndex: 0
            }

            Label {
                text: "Data bits:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: dataBitsSpin
                from: 5
                to: 8
                value: 8
                Layout.fillWidth: true
            }

            Label {
                text: "Stop bits:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: stopBitsCombo
                Layout.fillWidth: true
                model: ["1", "2"]
                currentIndex: 0
            }

            Label {
                text: "Slave ID:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: slaveSpin
                from: 1
                to: 247
                value: 1
                Layout.fillWidth: true
            }
        }
    }
}
