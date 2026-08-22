pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import LoggerKit.Theme

// TAB 1: Scaling & Alarms
Rectangle {
    id: root
    color: AppColors.surfaceContainerLow; radius: AppTheme.cardRadius
    border.color: AppColors.outlineVariant; border.width: 1

    // ── Expose form fields ──
    property alias dMinThreshold: dMinThreshold
    property alias dMaxThreshold: dMaxThreshold
    property alias dDecimals: dDecimals
    property alias dScalingMode: dScalingMode
    property alias dLinearA: dLinearA
    property alias dLinearB: dLinearB
    property alias dRawMin: dRawMin
    property alias dRawMax: dRawMax
    property alias dScaleMin: dScaleMin
    property alias dScaleMax: dScaleMax
    property alias dCoeffJson: dCoeffJson

    ColumnLayout {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 20
        spacing: 8

        Text { text: qsTr("Scaling & Alarms"); color: AppColors.accentColor; font.bold: true; font.pixelSize: AppTypography.titleSmall.pixelSize }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: AppColors.outlineVariant }

        // Use a 2-column grid for compact threshold + scaling layout
        GridLayout {
            columns: 4; Layout.fillWidth: true; columnSpacing: 15; rowSpacing: 8

            Text { text: qsTr("Min threshold:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            TextField { id: dMinThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
            Text { text: qsTr("Max threshold:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            TextField { id: dMaxThreshold; Layout.fillWidth: true; placeholderText: text.length > 0 ? "" : "Empty = disabled"; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }

            Text { text: qsTr("Decimals:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            SpinBox { id: dDecimals; from: 0; to: 6; value: 4; Layout.fillWidth: true }
        }

        Item { Layout.preferredHeight: 8 }

        Text { text: qsTr("Scaling mode:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
        ComboBox {
            id: dScalingMode; Layout.fillWidth: true; Layout.maximumWidth: 400
            model: ["No scaling (raw value)", "Linear (y = ax + b)", "Two-point mapping", "Advanced (JSON)"]
        }

        StackLayout {
            Layout.fillWidth: true; currentIndex: dScalingMode.currentIndex
            Item { implicitHeight: 0 }
            RowLayout {
                spacing: 8
                Text { text: qsTr("a:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                TextField { id: dLinearA; Layout.fillWidth: true; text: qsTr("1"); inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                Text { text: qsTr("b:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                TextField { id: dLinearB; Layout.fillWidth: true; text: qsTr("0"); inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
            }
            ColumnLayout {
                spacing: AppTheme.spacingS
                RowLayout {
                    spacing: 8
                    Text { text: qsTr("RawMin:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 60 }
                    TextField { id: dRawMin; text: qsTr("4000"); Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                    Text { text: qsTr("Max:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField { id: dRawMax; text: qsTr("20000"); Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                }
                RowLayout {
                    spacing: 8
                    Text { text: qsTr("ScaleMin:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize; Layout.preferredWidth: 60 }
                    TextField { id: dScaleMin; text: qsTr("4"); Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                    Text { text: qsTr("Max:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField { id: dScaleMax; text: qsTr("20"); Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                }
            }
            TextField { id: dCoeffJson; text: qsTr("{}"); Layout.fillWidth: true; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
        }
    }
}
