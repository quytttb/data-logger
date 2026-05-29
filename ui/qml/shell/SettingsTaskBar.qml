import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

Item {
    id: root
    implicitHeight: 64

    property int settingsTabIndex: 0
    property bool isConfigChanged: false
    property bool hasSelectedSensor: false
    property bool isAddMode: true // true for Add sensor, false for Edit sensor
    property int sensorSubTabIndex: 0
    property bool hasSelectedDio: false
    property string sensorType: "ANALOG"   // Current sensor type being edited

    signal tabSelected(int idx)
    signal sensorSubTabSelected(int idx)
    
    // Actions for config tabs (General, Connection, Server)
    signal saveConfig()
    signal cancelConfig()
    
    // Actions for Sensors list tab
    signal addSensor()
    signal editSelectedSensor()
    signal deleteSelectedSensor()
    
    // Actions for Sensor form (Add/Edit)
    signal saveSensorForm()
    signal cancelSensorForm()

    // Actions for Digital I/O
    signal deleteSelectedDio()

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // ── LEFT SIDE ──

        // TabBar (Visible in Tab 0-3)
        TabBar {
            visible: root.settingsTabIndex < 4
            Layout.alignment: Qt.AlignLeft
            currentIndex: root.settingsTabIndex
            onCurrentIndexChanged: {
                if (root.settingsTabIndex !== currentIndex && currentIndex < 4)
                    root.tabSelected(currentIndex)
            }

            TabButton {
                text: "General"
                icon.source: "../../../assets/icons/settings.svg"
                width: implicitWidth + 40
            }
            TabButton {
                text: "Connection"
                icon.source: "../../../assets/icons/connection.svg"
                width: implicitWidth + 40
            }
            TabButton {
                text: "Server"
                icon.source: "../../../assets/icons/export.svg"
                width: implicitWidth + 40
            }
            TabButton {
                text: "Sensors"
                icon.source: "../../../assets/icons/sensors.svg"
                width: implicitWidth + 40
            }
        }

        // Sub-tab navigation for Sensor Form (Visible in Tab 4)
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

                TabButton {
                    text: "Basic && Modbus"
                    width: implicitWidth + 30
                }
                TabButton {
                    text: "Scaling && Alarms"
                    width: implicitWidth + 30
                    visible: root.sensorType === "ANALOG"
                }
                TabButton {
                    text: "Digital I/O"
                    width: implicitWidth + 30
                    visible: !root.isAddMode && root.sensorType === "ANALOG"
                }
            }
        }

        Item { Layout.fillWidth: true } // Spacer

        // ── RIGHT SIDE ──

        // Config actions (General, Connection, Server — tabs 0, 1, 2)
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
                text: "Save"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
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
                visible: root.hasSelectedSensor
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                icon.source: "../../../assets/icons/delete.svg"
                icon.color: Theme.textOnColoredBtn
                icon.width: 18
                icon.height: 18
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStop
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                onClicked: root.deleteSelectedSensor()
            }

            Button {
                visible: root.hasSelectedSensor
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                icon.source: "../../../assets/icons/edit.svg"
                icon.color: Theme.textOnColoredBtn
                icon.width: 18
                icon.height: 18
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.accent
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                onClicked: root.editSelectedSensor()
            }

            Button {
                text: "+ Add"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
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

            // Detach linked DI/DO (Digital I/O sub-tab)
            Button {
                visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                icon.source: "../../../assets/icons/delete.svg"
                icon.color: Theme.textOnColoredBtn
                icon.width: 18
                icon.height: 18
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStop
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                onClicked: root.deleteSelectedDio()
            }

            Rectangle { width: 1; height: 28; color: Theme.borderDefault; Layout.alignment: Qt.AlignVCenter; visible: root.sensorSubTabIndex === 2 && root.hasSelectedDio }

            Button {
                text: "Cancel"
                font.bold: true
                Layout.preferredHeight: 44
                onClicked: root.cancelSensorForm()
            }
            
            Button {
                text: "Save"
                font.pixelSize: 12; font.bold: true
                Layout.preferredHeight: 44
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.btnStart
                    opacity: parent.pressed ? 0.75 : 1.0
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: Theme.textOnColoredBtn
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.saveSensorForm()
            }
        }
    }
}
