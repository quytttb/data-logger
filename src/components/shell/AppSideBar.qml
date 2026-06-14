pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme
import DataLogger.Core

Rectangle {
    id: sideBarRoot
    implicitWidth: 200
    color: AppColors.surface

    property int currentTab: 0
    signal selectTab(int index)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Column {
            id: navColumn
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: 5

                delegate: ItemDelegate {
                    id: navDelegate
                    width: sideBarRoot.width
                    implicitHeight: 56
                    required property int index
                    readonly property int tabIdx: index
                    readonly property bool isActive: sideBarRoot.currentTab === tabIdx
                    highlighted: isActive
                    padding: 0

                    background: Rectangle {
                        anchors.fill: parent
                        color: navDelegate.isActive ? AppColors.accentContainer
                             : navDelegate.hovered ? AppColors.hoverFill : "transparent"

                        Rectangle {
                            width: 4
                            height: parent.height
                            color: navDelegate.isActive ? AppColors.primaryColor : "transparent"
                        }
                    }

                    text: ["Monitor", "History", "Trending", "Settings", "Modbus tester"][navDelegate.index]
                    font: AppTypography.bodyMedium
                    font.weight: Font.Bold
                    palette.buttonText: navDelegate.isActive ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
                    icon.source: ["qrc:/qt/qml/DataLogger/Components/resources/icons/monitor.svg", "qrc:/qt/qml/DataLogger/Components/resources/icons/history.svg", "qrc:/qt/qml/DataLogger/Components/resources/icons/chart.svg", "qrc:/qt/qml/DataLogger/Components/resources/icons/settings.svg", "qrc:/qt/qml/DataLogger/Components/resources/icons/tester.svg"][navDelegate.index]
                    icon.color: navDelegate.isActive ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
                    icon.width: 18
                    icon.height: 18
                    spacing: 12
                    leftPadding: 16

                    onClicked: sideBarRoot.selectTab(navDelegate.tabIdx)
                }
            }
        }

        Item { Layout.fillHeight: true }

        Button {
            id: themeBtn
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 4
            implicitHeight: 36
            text: SettingsController.theme === "dark" ? "Light mode" : "Dark mode"
            font: AppTypography.labelMedium

            background: Rectangle {
                anchors.fill: parent
                radius: AppTheme.listItemRadius
                color: themeBtn.down ? AppColors.hoverFill
                     : themeBtn.hovered ? AppColors.hoverFill : "transparent"
                border.color: AppColors.outlineVariant
                border.width: 1
            }

            contentItem: Text {
                text: themeBtn.text
                font: themeBtn.font
                color: AppColors.primaryText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                const next = SettingsController.theme === "dark" ? "light" : "dark"
                SettingsController.saveTheme(next)
            }
        }

        Button {
            id: exitBtn
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            implicitHeight: 44
            text: "Exit"
            font: AppTypography.labelLarge

            background: Rectangle {
                anchors.fill: parent
                radius: AppTheme.listItemRadius
                color: exitBtn.down ? Qt.darker(AppColors.error, 1.15)
                     : exitBtn.hovered ? Qt.lighter(AppColors.error, 1.08) : AppColors.error
            }

            contentItem: Text {
                text: exitBtn.text
                font: exitBtn.font
                color: AppColors.onPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: Qt.quit()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: AppColors.surface

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: AppColors.dividerLine
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 3

                Text {
                    id: clockLabel
                    text: Qt.formatDateTime(new Date(), "dd/MM/yyyy  HH:mm:ss")
                    font: AppTypography.labelMedium
                    color: AppColors.onSurfaceVariant
                }

                Text {
                    text: MonitorController.statusText
                    font: AppTypography.labelSmall
                    font.weight: Font.Bold
                    color: {
                        var m = MonitorController.statusMode;
                        if (m === 1)
                            return AppColors.success;
                        if (m === 2)
                            return AppColors.error;
                        return AppColors.onSurfaceVariant;
                    }
                }

                RowLayout {
                    id: ftpStatusRow
                    spacing: 5

                    readonly property color statusColor: {
                        if (!ReportController.isRunning)
                            return AppColors.onSurfaceVariant;
                        var s = ReportController.lastStatus;
                        if (s.indexOf("FAIL") >= 0 || s.indexOf("ERROR") >= 0)
                            return AppColors.error;
                        if (s.indexOf("OK") >= 0)
                            return AppColors.success;
                        return AppColors.accentColor;
                    }

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: ftpStatusRow.statusColor
                    }
                    Text {
                        text: {
                            if (!ReportController.isRunning)
                                return "FTP off";
                            var s = ReportController.lastStatus;
                            if (s.indexOf("FAIL") >= 0 || s.indexOf("ERROR") >= 0)
                                return "FTP error";
                            if (ReportController.pendingCount > 0)
                                return "FTP (%1 pending)".arg(ReportController.pendingCount);
                            return "FTP on";
                        }
                        font: AppTypography.labelSmall
                        font.weight: Font.Bold
                        color: ftpStatusRow.statusColor
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "dd/MM/yyyy  HH:mm:ss")
    }
}
