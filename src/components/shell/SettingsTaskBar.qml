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
            TabButton { text: "General";    icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/settings.svg";    width: implicitWidth + 40 }
            TabButton { text: "Connection"; icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/connection.svg";  width: implicitWidth + 40 }
            TabButton { text: "Server";     icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/export.svg";      width: implicitWidth + 40 }
            TabButton { text: "Sensors";    icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/sensors.svg";     width: implicitWidth + 40 }
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
                TabButton { text: "Basic && Modbus";   width: implicitWidth + 30 }
                TabButton { text: "Scaling && Alarms"; width: implicitWidth + 30; visible: root.sensorType === "ANALOG" }
                TabButton { text: "Digital I/O";       width: implicitWidth + 30; visible: !root.isAddMode && root.sensorType === "ANALOG" }
            }
        }

        Item { Layout.fillWidth: true }

        // Config actions (tabs 0–2)
        RowLayout {
            visible: root.settingsTabIndex >= 0 && root.settingsTabIndex <= 2 && root.isConfigChanged
            spacing: 8

            Button {
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
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/delete.svg"
                icon.color: Theme.textOnColoredBtn; icon.width: 18; icon.height: 18
                background: Rectangle { radius: Theme.radiusSmall; color: Theme.btnStop; opacity: deleteSensorBtn.pressed ? 0.75 : 1.0 }
                onClicked: root.deleteSelectedSensor()
            }

            Button {
                id: editSensorBtn
                visible: root.hasSelectedSensor
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/edit.svg"
                icon.color: Theme.textOnColoredBtn; icon.width: 18; icon.height: 18
                background: Rectangle { radius: Theme.radiusSmall; color: Theme.accent; opacity: editSensorBtn.pressed ? 0.75 : 1.0 }
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
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/delete.svg"
                icon.color: Theme.textOnColoredBtn; icon.width: 18; icon.height: 18
                background: Rectangle { radius: Theme.radiusSmall; color: Theme.btnStop; opacity: deleteDioBtn.pressed ? 0.75 : 1.0 }
                onClicked: root.deleteSelectedDio()
            }

            Rectangle {
                implicitWidth: 1; implicitHeight: 28
                color: Theme.borderDefault
                Layout.alignment: Qt.AlignVCenter
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
            }

            Button {
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
