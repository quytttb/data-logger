pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Core
import LoggerKit.Theme

Rectangle {
    id: root
    color: AppColors.surfaceContainerLow; radius: AppTheme.cardRadius
    border.color: AppColors.outlineVariant; border.width: 1

    property bool isTesterMode: false

    readonly property string sensorType: {
        let r = dRegTypeItem.currentText
        if (r === "Discrete Inputs") return "DI"
        if (r === "Coils") return "DO"
        return "ANALOG"
    }

    readonly property bool isAnalog: sensorType === "ANALOG"
    readonly property bool isDI: sensorType === "DI"
    readonly property bool isDO: sensorType === "DO"
    readonly property bool isDigital: isDI || isDO

    property alias dActive: dActive
    property alias dName: dName
    property alias dSensorSymbol: dSensorSymbol
    property alias dUnit: dUnit
    property alias dPollInterval: dPollInterval
    property alias dReportIdx: dReportIdx
    property alias dSlave: dSlave
    property alias dAddr: dAddr
    property alias dRegType: dRegTypeItem
    property alias dDataType: dDataType
    property alias dDataFmt: dDataFmt

    RowLayout {
        anchors.fill: parent; anchors.margins: 20
        spacing: AppTheme.spacingL

        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: qsTr("Basic Info"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Active:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.fillWidth: true }
                Switch { id: dActive; checked: true }
            }

            Text { text: qsTr("Ký hiệu cảm biến:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox {
                id: dSensorSymbol
                Layout.fillWidth: true
                visible: root.isAnalog
                editable: true
                model: SensorSymbols.symbols
            }

            Text { text: qsTr("Name:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            TextField { id: dName; Layout.fillWidth: true; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }

            Text { text: qsTr("Unit:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox {
                id: dUnit; Layout.fillWidth: true; visible: root.isAnalog
                editable: true
                model: [
                    "°C", "°F", "%", "%RH",
                    "pH", "mg/L", "µg/L", "NTU",
                    "m³/h", "m³/s", "L/min", "L/h",
                    "m³", "m²", "m", "mm",
                    "mV", "V", "mA", "A",
                    "kPa", "Pa", "bar", "psi",
                    "dB", "dBA", "lux",
                    "ppm", "ppb", "mg/m³"
                ]
            }

            Text { text: qsTr("Poll interval (s):"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: !root.isTesterMode && root.isAnalog }
            SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true; visible: !root.isTesterMode && root.isAnalog }

            Text { text: qsTr("Report column index:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: !root.isTesterMode && root.isAnalog }
            SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true; visible: !root.isTesterMode && root.isAnalog }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 8
            Text { text: qsTr("Modbus Settings"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

            RowLayout {
                spacing: AppTheme.spacingS; Layout.fillWidth: true
                Text { text: qsTr("Slave ID:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dSlave; from: 1; to: 247; value: 1; Layout.fillWidth: true }
            }

            RowLayout {
                spacing: AppTheme.spacingS; Layout.fillWidth: true
                Text { text: qsTr("Address:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 80 }
                SpinBox { id: dAddr; from: 0; to: 65535; value: 0; Layout.fillWidth: true; editable: true }
            }

            Text { text: qsTr("Register type:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            ComboBox {
                id: dRegTypeItem; Layout.fillWidth: true
                model: ["Invalid", "Discrete Inputs", "Coils", "Input Registers", "Holding Registers"]
            }

            Text { text: qsTr("Data type:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox { id: dDataType; model: AppDefaults.dataTypes; Layout.fillWidth: true; visible: root.isAnalog }

            Text { text: qsTr("Endian format:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox { id: dDataFmt; model: AppDefaults.byteOrders; Layout.fillWidth: true; visible: root.isAnalog }
        }
    }
}
