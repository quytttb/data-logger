pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

ElevatedPane {
    id: root
    padding: 20
    contentSpacing: 0

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

    // Dropdown-only: no free-text typing. A previously-saved value that is not
    // in the standard list is merged into the model so it stays visible.
    readonly property var symbolBase: SensorSymbols.symbols.slice(0)
    readonly property var unitBase: [
        "°C", "°F", "%", "%RH",
        "pH", "mg/L", "µg/L", "NTU",
        "m³/h", "m³/s", "L/min", "L/h",
        "m³", "m²", "m", "mm",
        "mV", "V", "mA", "A",
        "kPa", "Pa", "bar", "psi",
        "dB", "dBA", "lux",
        "ppm", "ppb", "mg/m³"
    ]

    function setSymbolValue(v) {
        let list = root.symbolBase.slice(0)
        if (v && list.indexOf(v) < 0) list.push(v)
        dSensorSymbol.model = list
        dSensorSymbol.currentIndex = v ? list.indexOf(v) : -1
    }

    function setUnitValue(v) {
        let list = root.unitBase.slice(0)
        if (v && list.indexOf(v) < 0) list.push(v)
        dUnit.model = list
        dUnit.currentIndex = v ? list.indexOf(v) : -1
    }

    readonly property string currentSymbol: dSensorSymbol.currentText
    readonly property string currentUnit: dUnit.currentText

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
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

            Text { text: qsTr("Sensor symbol:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox {
                id: dSensorSymbol
                Layout.fillWidth: true
                visible: root.isAnalog
                model: root.symbolBase
            }

            Text { text: qsTr("Name:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            TextField { id: dName; Layout.fillWidth: true; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }

            Text { text: qsTr("Unit:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; visible: root.isAnalog }
            ComboBox {
                id: dUnit; Layout.fillWidth: true; visible: root.isAnalog
                model: root.unitBase
            }

            RowLayout {
                spacing: AppTheme.spacingS; Layout.fillWidth: true
                visible: !root.isTesterMode && root.isAnalog
                Text { text: qsTr("Poll interval (s):"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 145; elide: Text.ElideRight }
                SpinBox { id: dPollInterval; from: 1; to: 3600; value: 3; Layout.fillWidth: true }
                Text { text: qsTr("Report column:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 110; elide: Text.ElideRight }
                SpinBox { id: dReportIdx; from: 0; to: 99; value: 0; Layout.fillWidth: true }
            }
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
