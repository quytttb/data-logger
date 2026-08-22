pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    implicitHeight: 64

    property int settingsTabIndex: 0
    property bool isConfigChanged: false
    property bool hasSelectedSensor: false
    property bool isAddMode: true
    property int sensorSubTabIndex: 0
    property bool hasSelectedDio: false
    property string sensorType: "ANALOG"

    signal tabSelected(int idx)
    signal sensorSubTabSelected(int idx)
    signal saveConfig()
    signal cancelConfig()
    signal addSensor()
    signal editSelectedSensor()
    signal deleteSelectedSensor()
    signal saveSensorForm()
    signal cancelSensorForm()
    signal deleteSelectedDio()

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        TabBar {
            visible: root.settingsTabIndex < 4
            Layout.alignment: Qt.AlignLeft
            currentIndex: root.settingsTabIndex
            onCurrentIndexChanged: {
                if (root.settingsTabIndex !== currentIndex && currentIndex < 4)
                    root.tabSelected(currentIndex)
            }
            background: Rectangle { color: "transparent" }
            ThemedTabButton { text: qsTr("General");    iconName: "cog";    width: implicitWidth + 40 }
            ThemedTabButton { text: qsTr("Connection"); iconName: "link";   width: implicitWidth + 40 }
            ThemedTabButton { text: qsTr("Server");     iconName: "download"; width: implicitWidth + 40 }
            ThemedTabButton { text: qsTr("Sensors");    iconName: "chip";     width: implicitWidth + 40 }
        }

        RowLayout {
            visible: root.settingsTabIndex === 4
            spacing: AppTheme.spacingS

            TabBar {
                id: sensorSubTabBar
                Layout.alignment: Qt.AlignVCenter
                currentIndex: root.sensorSubTabIndex
                onCurrentIndexChanged: {
                    if (root.sensorSubTabIndex !== currentIndex)
                        root.sensorSubTabSelected(currentIndex)
                }
                background: Rectangle { color: "transparent" }
                ThemedTabButton { text: qsTr("Basic && Modbus");   width: implicitWidth + 30 }
                ThemedTabButton { text: qsTr("Scaling && Alarms"); width: implicitWidth + 30; visible: root.sensorType === "ANALOG" }
                ThemedTabButton { text: qsTr("Digital I/O");       width: implicitWidth + 30; visible: !root.isAddMode && root.sensorType === "ANALOG" }
            }
        }

        Item { Layout.fillWidth: true }

        // Config actions (tabs 0–2)
        RowLayout {
            visible: root.settingsTabIndex >= 0 && root.settingsTabIndex <= 2 && root.isConfigChanged
            spacing: 8

            AppButton {
                text: qsTr("Cancel")
                kind: AppButton.Neutral
                font.bold: true
                Layout.preferredHeight: 44
                onClicked: root.cancelConfig()
            }

            AppButton {
                text: qsTr("Save")
                font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                Layout.preferredHeight: 44
                fillColor: AppColors.success
                onClicked: root.saveConfig()
            }
        }

        // Sensors list actions (Tab 3)
        RowLayout {
            visible: root.settingsTabIndex === 3
            spacing: 8

            AppButton {
                visible: root.hasSelectedSensor
                iconName: "trashCan"
                fillColor: AppColors.error
                onClicked: root.deleteSelectedSensor()
            }

            AppButton {
                visible: root.hasSelectedSensor
                iconName: "pencil"
                onClicked: root.editSelectedSensor()
            }

            AppButton {
                text: qsTr("+ Add")
                font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                Layout.preferredHeight: 44
                fillColor: AppColors.success
                onClicked: root.addSensor()
            }
        }

        // Sensor Form actions (Tab 4)
        RowLayout {
            visible: root.settingsTabIndex === 4
            spacing: 8

            AppButton {
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
                iconName: "trashCan"
                fillColor: AppColors.error
                onClicked: root.deleteSelectedDio()
            }

            Rectangle {
                implicitWidth: 1; implicitHeight: 28
                color: AppColors.outlineVariant
                Layout.alignment: Qt.AlignVCenter
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
            }

            AppButton {
                text: qsTr("Cancel")
                kind: AppButton.Neutral
                font.bold: true
                Layout.preferredHeight: 44
                onClicked: root.cancelSensorForm()
            }

            AppButton {
                text: qsTr("Save")
                font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                Layout.preferredHeight: 44
                fillColor: AppColors.success
                onClicked: root.saveSensorForm()
            }
        }
    }
}
