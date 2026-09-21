pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    implicitHeight: 64

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: AppTheme.spacingS

        // Status pill: live monitoring state (read-only indicator, not a control)
        Rectangle {
            id: statusPill
            readonly property color stateColor: MonitorController.statusMode === MonitorController.StatusError
                ? AppColors.error
                : MonitorController.statusMode === MonitorController.StatusOk
                    ? AppColors.success
                    : AppColors.onSurfaceVariant

            Layout.preferredHeight: 44
            Layout.preferredWidth: Math.min(statusRow.implicitWidth + 36, 300)
            Layout.maximumWidth: 300
            radius: AppTheme.listItemRadius
            color: AppColors.surfaceContainerHigh
            border.width: 1
            border.color: Qt.rgba(statusPill.stateColor.r, statusPill.stateColor.g, statusPill.stateColor.b, 0.5)
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: AppTheme.spacingS

                Rectangle {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    radius: width / 2
                    color: statusPill.stateColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Label {
                    text: MonitorController.statusText
                    color: statusPill.stateColor
                    font.pixelSize: AppTypography.titleMedium.pixelSize
                    font.bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Rectangle {
            id: ftpPill
            readonly property color stateColor: !ReportController.isRunning
                ? AppColors.onSurfaceVariant
                : ReportController.uploadState === ReportController.UploadFailed ? AppColors.error
                : ReportController.uploadState === ReportController.UploadOk ? AppColors.success
                : AppColors.accentColor
            readonly property string stateText: !ReportController.isRunning ? qsTr("FTP Off")
                : ReportController.uploadState === ReportController.UploadFailed ? qsTr("FTP Failed")
                : ReportController.uploadState === ReportController.UploadOk ? qsTr("FTP OK")
                : qsTr("FTP Running")

            Layout.preferredHeight: 44
            Layout.preferredWidth: ftpRow.implicitWidth + 28
            radius: AppTheme.listItemRadius
            color: AppColors.surfaceContainerHigh
            border.width: 1
            border.color: AppColors.withAlpha(stateColor, 0.5)

            RowLayout {
                id: ftpRow
                anchors.centerIn: parent
                spacing: AppTheme.spacingS

                Rectangle {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    radius: width / 2
                    color: ftpPill.stateColor
                }
                Label {
                    text: ftpPill.stateText
                    color: ftpPill.stateColor
                    font.pixelSize: AppTypography.titleMedium.pixelSize
                    font.bold: true
                }
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: AppTheme.spacingS

            Rectangle {
                Layout.preferredHeight: 44
                Layout.preferredWidth: clockDate.implicitWidth + 28
                radius: AppTheme.listItemRadius
                color: AppColors.surfaceContainerHigh
                border.width: 1
                border.color: AppColors.withAlpha(AppColors.onSurfaceVariant, 0.35)

                Text {
                    id: clockDate
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), SettingsController.dateFormat)
                    font.pixelSize: AppTypography.titleLarge.pixelSize
                    font.bold: true
                    color: AppColors.primaryText
                }
            }

            Rectangle {
                Layout.preferredHeight: 44
                Layout.preferredWidth: clockTime.implicitWidth + 28
                radius: AppTheme.listItemRadius
                color: AppColors.surfaceContainerHigh
                border.width: 1
                border.color: AppColors.withAlpha(AppColors.onSurfaceVariant, 0.35)

                Text {
                    id: clockTime
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), SettingsController.timeFormat)
                    font.pixelSize: AppTypography.headlineSmall.pixelSize
                    font.bold: true
                    color: AppColors.primaryText
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()
            clockTime.text = Qt.formatDateTime(now, SettingsController.timeFormat)
            clockDate.text = Qt.formatDateTime(now, SettingsController.dateFormat)
        }
    }
}
