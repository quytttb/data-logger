import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Theme

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
            ThemedTabButton { text: "General";    iconName: "cog";    width: implicitWidth + 40 }
            ThemedTabButton { text: "Connection"; iconName: "link";   width: implicitWidth + 40 }
            ThemedTabButton { text: "Server";     iconName: "download"; width: implicitWidth + 40 }
            ThemedTabButton { text: "Sensors";    iconName: "chip";     width: implicitWidth + 40 }
        }

        RowLayout {
            visible: root.settingsTabIndex === 4
            spacing: 10

            TabBar {
                id: sensorSubTabBar
                Layout.alignment: Qt.AlignVCenter
                currentIndex: root.sensorSubTabIndex
                onCurrentIndexChanged: {
                    if (root.sensorSubTabIndex !== currentIndex)
                        root.sensorSubTabSelected(currentIndex)
                }
                background: Rectangle { color: "transparent" }
                ThemedTabButton { text: "Basic && Modbus";   width: implicitWidth + 30 }
                ThemedTabButton { text: "Scaling && Alarms"; width: implicitWidth + 30; visible: root.sensorType === "ANALOG" }
                ThemedTabButton { text: "Digital I/O";       width: implicitWidth + 30; visible: !root.isAddMode && root.sensorType === "ANALOG" }
            }
        }

        Item { Layout.fillWidth: true }

        // Config actions (tabs 0–2)
        RowLayout {
            visible: root.settingsTabIndex >= 0 && root.settingsTabIndex <= 2 && root.isConfigChanged
            spacing: 8

            ThemedButton {
                text: "Cancel"
                font.bold: true
                Layout.preferredHeight: 44
                onClicked: root.cancelConfig()
            }

            Button {
                id: saveConfigBtn
                text: "Save"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: saveConfigBtn.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: saveConfigBtn.text; font: saveConfigBtn.font
                    color: Theme.textOnColoredBtn
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.saveConfig()
            }
        }

        // Sensors list actions (Tab 3)
        RowLayout {
            visible: root.settingsTabIndex === 3
            spacing: 8

            Button {
                id: deleteSensorBtn
                visible: root.hasSelectedSensor
                implicitWidth: 44
                implicitHeight: 44
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                contentItem: Item {
                    anchors.fill: parent
                    UiIcon {
                        anchors.centerIn: parent
                        name: "trashCan"
                        size: 18
                        iconColor: AppColors.buttonIconOnFilled
                    }
                }
                background: Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMedium
                    color: Theme.btnStop
                    opacity: deleteSensorBtn.pressed ? 0.75 : 1.0
                }
                onClicked: root.deleteSelectedSensor()
            }

            Button {
                id: editSensorBtn
                visible: root.hasSelectedSensor
                implicitWidth: 44
                implicitHeight: 44
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                contentItem: Item {
                    anchors.fill: parent
                    UiIcon {
                        anchors.centerIn: parent
                        name: "pencil"
                        size: 18
                        iconColor: AppColors.buttonIconOnFilled
                    }
                }
                background: Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMedium
                    color: Theme.accent
                    opacity: editSensorBtn.pressed ? 0.75 : 1.0
                }
                onClicked: root.editSelectedSensor()
            }

            Button {
                id: addBtn
                text: "+ Add"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: addBtn.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: addBtn.text; font: addBtn.font
                    color: Theme.textOnColoredBtn
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.addSensor()
            }
        }

        // Sensor Form actions (Tab 4)
        RowLayout {
            visible: root.settingsTabIndex === 4
            spacing: 8

            Button {
                id: deleteDioBtn
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
                implicitWidth: 44
                implicitHeight: 44
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                contentItem: Item {
                    anchors.fill: parent
                    UiIcon {
                        anchors.centerIn: parent
                        name: "trashCan"
                        size: 18
                        iconColor: AppColors.buttonIconOnFilled
                    }
                }
                background: Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMedium
                    color: Theme.btnStop
                    opacity: deleteDioBtn.pressed ? 0.75 : 1.0
                }
                onClicked: root.deleteSelectedDio()
            }

            Rectangle {
                implicitWidth: 1; implicitHeight: 28
                color: Theme.borderDefault
                Layout.alignment: Qt.AlignVCenter
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
            }

            ThemedButton {
                text: "Cancel"
                font.bold: true
                Layout.preferredHeight: 44
                onClicked: root.cancelSensorForm()
            }

            Button {
                id: saveSensorFormBtn
                text: "Save"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: saveSensorFormBtn.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: saveSensorFormBtn.text; font: saveSensorFormBtn.font
                    color: Theme.textOnColoredBtn
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.saveSensorForm()
            }
        }
    }
}
