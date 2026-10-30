pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import LoggerKit.Theme
import LoggerKit.Components

// TAB 1: Scaling & Alarms
//
// Hiệu chuẩn đa điểm nằm ở màn Monitor (nút Calibrate trên thẻ cảm biến) —
// tab này chỉ giữ nhập hệ số thủ công (a, b) cho admin và lối JSON nâng cao.
ElevatedPane {
    id: root
    padding: 20
    contentSpacing: 0

    // ── Expose form fields ──
    property alias dMinThreshold: dMinThreshold
    property alias dMaxThreshold: dMaxThreshold
    property alias dDecimals: dDecimals
    property alias dScalingMode: dScalingMode
    property alias dLinearA: dLinearA
    property alias dLinearB: dLinearB
    property alias dCoeffJson: dCoeffJson

    ColumnLayout {
        Layout.fillWidth: true
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

            Text { text: qsTr("Decimal places:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
            SpinBox { id: dDecimals; from: 0; to: 6; value: 4; Layout.fillWidth: true }
        }

        Item { Layout.preferredHeight: 8 }

        Text { text: qsTr("Scaling mode:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
        ComboBox {
            id: dScalingMode; Layout.fillWidth: true; Layout.maximumWidth: 400
            model: ["No scaling (raw value)", "Linear (y = a·x + b)", "Advanced (JSON)"]
        }

        StackLayout {
            Layout.fillWidth: true; currentIndex: dScalingMode.currentIndex
            Item { implicitHeight: 0 }
            ColumnLayout {
                spacing: 4
                RowLayout {
                    spacing: 8
                    Text { text: qsTr("a:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField { id: dLinearA; Layout.fillWidth: true; text: qsTr("1"); inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                    Text { text: qsTr("b:"); color: AppColors.onSurfaceVariant; font.pixelSize: AppTypography.bodyMedium.pixelSize }
                    TextField { id: dLinearB; Layout.fillWidth: true; text: qsTr("0"); inputMethodHints: Qt.ImhFormattedNumbersOnly; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
                }
                Text {
                    text: qsTr("For 2..N point calibration, use Calibrate on the Monitor screen.")
                    color: AppColors.textFaint
                    font.pixelSize: AppTypography.bodySmall.pixelSize
                }
            }
            TextField { id: dCoeffJson; text: qsTr("{}"); Layout.fillWidth: true; EnterKeyAction.actionId: EnterKeyAction.None; EnterKeyAction.label: qsTr("OK") }
        }
    }
}
