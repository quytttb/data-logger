pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: sideBarRoot
    implicitWidth: AppTheme.railWidth
    color: AppColors.navRail

    property int currentTab: 0
    signal selectTab(int index)
    signal restartRequested()

    // Right-edge divider separating the rail from the main canvas.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: AppColors.dividerLine
        z: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 76

            Image {
                anchors.centerIn: parent
                source: "qrc:/qt/qml/LoggerKit/Components/resources/icons/brand_4m_technologies_blue.svg"
                sourceSize: Qt.size(60, 60)
                fillMode: Image.PreserveAspectFit
            }
        }

        Column {
            id: navColumn
            Layout.fillWidth: true
            spacing: AppTheme.navItemSpacing

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
                                size: AppTheme.iconSizeLg
                                iconColor: navDelegate.isActive
                                         ? AppColors.accentContainerFg
                                         : AppColors.onSurfaceVariant
                            }
                        }

                        Text {
                            text: [qsTr("Monitor"), qsTr("History"), qsTr("Trending"), qsTr("Settings"), qsTr("Tester")][navDelegate.index]
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

        AppButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: AppTheme.spacingM
            iconName: "restart_alt"
            iconOnly: true
            kind: AppButton.Primary
            fillColor: AppColors.error
            tooltipText: qsTr("Restart device")
            onClicked: sideBarRoot.restartRequested()
        }
    }
}
