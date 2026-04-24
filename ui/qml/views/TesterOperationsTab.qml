import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight

    property alias regTypeCombo: regTypeCombo
    property alias dataTypeCombo: dataTypeCombo
    property alias dataFormatCombo: dataFormatCombo
    property alias scanStartSpin: scanStartSpin
    property alias scanEndSpin: scanEndSpin
    property alias scanCountSpin: scanCountSpin
    property alias slaveSpin: slaveSpin
    
    // Thuộc tính phục vụ cho chế độ Write
    property alias writeAddrSpin: writeAddrSpin
    property alias writeValSpin: writeValSpin
    property bool isReadMode: true

    // Coils / Discrete Inputs là kiểu boolean, không cần Data type & Endian
    readonly property bool isBooleanType: regTypeCombo.currentText === "Coils"
                                       || regTypeCombo.currentText === "Discrete Inputs"

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
                text: "Slave ID:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            SpinBox {
                id: slaveSpin
                from: 1; to: 247; value: 1
                Layout.fillWidth: true
            }

            Label {
                text: "Register type:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
            ComboBox {
                id: regTypeCombo
                Layout.fillWidth: true
                // Chỉ cho phép Holding/Coils khi ở Write Mode
                model: isReadMode ? ["Holding Registers", "Input Registers", "Coils", "Discrete Inputs"]
                                  : ["Holding Registers", "Coils"]
                currentIndex: 1 // Input Registers lúc mặc định (Read Mode)
            }

            // ── Data type (ẩn khi boolean) ────────────────────────
            Label {
                text: "Data type:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !isBooleanType
            }
            ComboBox {
                id: dataTypeCombo
                Layout.fillWidth: true
                model: ["int16", "uint16", "int32", "uint32", "float32"]
                currentIndex: 1
                visible: !isBooleanType
            }

            // ── Endian format (ẩn khi boolean) ────────────────────
            Label {
                text: "Endian format:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !isBooleanType
            }
            ComboBox {
                id: dataFormatCombo
                Layout.fillWidth: true
                model: ["AB", "BA", "ABCD", "CDAB"]
                currentIndex: 0
                visible: !isBooleanType
            }

            // ========================================================
            // CÁC TRƯỜNG DÀNH CHO READ MODE
            // ========================================================
            Label {
                text: "Start address:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: isReadMode
            }
            SpinBox {
                id: scanStartSpin
                from: 0; to: 65535; value: 0
                editable: true
                Layout.fillWidth: true
                visible: isReadMode
            }

            Label {
                text: "End address:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: isReadMode
            }
            SpinBox {
                id: scanEndSpin
                from: 0; to: 65535; value: 100
                editable: true
                Layout.fillWidth: true
                visible: isReadMode
            }

            Label {
                text: "Registers per read:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: isReadMode
            }
            SpinBox {
                id: scanCountSpin
                from: 1; to: 125; value: 8
                Layout.fillWidth: true
                visible: isReadMode
                ToolTip.visible: hovered
                ToolTip.text: "Number of consecutive registers read at each address (1–125)."
            }

            // ========================================================
            // CÁC TRƯỜNG DÀNH CHO WRITE MODE
            // ========================================================
            Label {
                text: "Write address:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !isReadMode
            }
            SpinBox {
                id: writeAddrSpin
                from: 0; to: 65535; value: 0
                editable: true
                Layout.fillWidth: true
                visible: !isReadMode
            }

            Label {
                text: "Write value:"
                color: Theme.textSecondary
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                visible: !isReadMode
            }
            SpinBox {
                id: writeValSpin
                from: -9999999; to: 9999999; value: 1
                editable: true
                Layout.fillWidth: true
                visible: !isReadMode
            }
        }
    }
}
