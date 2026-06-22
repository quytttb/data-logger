pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

Rectangle {
    id: sideBarRoot
    implicitWidth: AppTheme.railWidth
    color: AppColors.surfaceContainer

    property int currentTab: 0
    signal selectTab(int index)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 76

            Image {
                anchors.centerIn: parent
                source: "qrc:/qt/qml/DataLogger/Components/resources/icons/brand_4m_technologies_blue.svg"
                sourceSize: Qt.size(60, 60)
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                    if (mouse.button === Qt.LeftButton && Window.window)
                        Window.window.startSystemMove()
                }
            }
        }

        Column {
            id: navColumn
            Layout.fillWidth: true
            spacing: AppTheme.navItemSpacing + 8

            Repeater {
                model: 5

                delegate: ItemDelegate {
                    id: navDelegate
                    width: sideBarRoot.width
                    implicitHeight: AppTheme.navItemHeight
                    required property int index
                    readonly property int tabIdx: index
                    readonly property bool isActive: sideBarRoot.currentTab === tabIdx
                    padding: 4
                    hoverEnabled: true

                    background: Item {}

                    contentItem: ColumnLayout {
                        spacing: 4
                        anchors.fill: parent

                        Item {
                            Layout.preferredWidth: AppTheme.navPillWidth
                            Layout.preferredHeight: AppTheme.navPillHeight
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: AppTheme.navPillWidth
                                height: AppTheme.navPillHeight
                                radius: AppTheme.navPillRadius
                                visible: navDelegate.isActive
                                color: AppColors.accentContainer
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: AppTheme.navPillWidth
                                height: AppTheme.navPillHeight
                                radius: AppTheme.navPillRadius
                                visible: navDelegate.hovered && !navDelegate.isActive
                                color: AppColors.hoverFill
                            }

                            UiIcon {
                                anchors.centerIn: parent
                                name: ["viewDashboard", "history", "showChart", "cog", "codeBlocks"][navDelegate.index]
                                size: 24
                                iconColor: navDelegate.isActive
                                         ? AppColors.accentContainerFg
                                         : AppColors.onSurfaceVariant
                            }
                        }

                        Text {
                            text: ["Monitor", "History", "Trending", "Settings", "Tester"][navDelegate.index]
                            font.family: AppTypography.labelMedium.family
                            font.pixelSize: AppTypography.labelMedium.pixelSize
                            font.bold: navDelegate.isActive
                            color: navDelegate.isActive ? AppColors.accentContainerFg : AppColors.onSurfaceVariant
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    onClicked: sideBarRoot.selectTab(navDelegate.tabIdx)
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Exit Button (Centered flat icon button)
        Button {
            id: exitBtn
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            implicitWidth: 44
            implicitHeight: 44

            background: Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: exitBtn.pressed ? AppColors.error : AppColors.errorContainer
            }

            contentItem: Item {
                anchors.fill: parent
                UiIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 20
                    iconColor: AppColors.errorContainerFg
                }
            }

            onClicked: Qt.quit()
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: AppColors.dividerLine
            Layout.margins: 8
        }

        // Time and Status Column (Optimized for 7-inch touch)
        Column {
            width: parent.width
            spacing: 16
            Layout.bottomMargin: 12

            // Status Column (Line by Line)
            Column {
                width: parent.width
                spacing: 6

                // Modbus
                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: MonitorController.statusMode === 1 ? AppColors.success
                             : MonitorController.statusMode === 2 ? AppColors.error
                             : AppColors.onSurfaceVariant
                    }
                    Text {
                        text: "Modbus"
                        font.pixelSize: 10
                        color: AppColors.onSurfaceVariant
                        font.bold: true
                    }
                }

                // FTP
                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: {
                            if (!ReportController.isRunning) return AppColors.onSurfaceVariant;
                            var s = ReportController.lastStatus || "";
                            if (s.indexOf("FAIL") >= 0 || s.indexOf("ERROR") >= 0) return AppColors.error;
                            if (s.indexOf("OK") >= 0) return AppColors.success;
                            return AppColors.accentColor;
                        }
                    }
                    Text {
                        text: "FTP"
                        font.pixelSize: 10
                        color: AppColors.onSurfaceVariant
                        font.bold: true
                    }
                }
            }

            // Clock (Stacked numbers with seconds & year)
            Column {
                width: parent.width
                spacing: 4

                Text {
                    id: clockTimeLabel
                    width: parent.width
                    text: Qt.formatDateTime(new Date(), "HH\n:mm\n:ss")
                    font.family: AppTypography.labelMedium.family
                    font.pixelSize: 18
                    font.bold: true
                    color: AppColors.primaryText
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.0
                }

                Text {
                    id: clockDateLabel
                    width: parent.width
                    text: Qt.formatDateTime(new Date(), "dd/MM/yyyy")
                    font.pixelSize: 11
                    color: AppColors.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockTimeLabel.text = Qt.formatDateTime(new Date(), "HH\n:mm\n:ss")
            clockDateLabel.text = Qt.formatDateTime(new Date(), "dd/MM/yyyy")
        }
    }
}
