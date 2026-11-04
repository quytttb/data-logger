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

    // Chỉ admin được sửa cấu hình; nút bị vô hiệu hóa nếu role khác lọt vào.
    enabled: AuthService.canConfigureSensors

    property int settingsTabIndex: 0
    property bool isConfigChanged: false
    property bool hasSelectedSensor: false
    property bool userListActive: false
    property bool userFormActive: false
    property bool hasSelectedUser: false
    property bool selfSelectedUser: false
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
    signal addUser()
    signal editSelectedUser()
    signal deleteSelectedUser()
    signal saveUserForm()
    signal cancelUserForm()

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        TabBar {
            visible: root.settingsTabIndex >= 0 && root.settingsTabIndex < 5
                     && !root.userFormActive
            Layout.alignment: Qt.AlignLeft
            currentIndex: root.settingsTabIndex >= 0 && root.settingsTabIndex < 5
                          ? root.settingsTabIndex : -1
            onCurrentIndexChanged: {
                if (root.settingsTabIndex >= 0 && root.settingsTabIndex < 5
                        && root.settingsTabIndex !== currentIndex
                        && currentIndex >= 0 && currentIndex < 5)
                    root.tabSelected(currentIndex)
            }
            background: Rectangle { color: "transparent" }
            ThemedTabButton { text: qsTr("General");    iconName: "cog";  iconOnly: true; width: AppTheme.buttonHeight + 24 }
            ThemedTabButton { text: qsTr("Connection"); iconName: "link"; iconOnly: true; width: AppTheme.buttonHeight + 24 }
            // Material Symbols: upload (E2C6), group (E7EF). Không sửa API kit dùng chung.
            ThemedTabButton { text: qsTr("Server");  iconGlyph: "\uE2C6"; iconOnly: true; width: AppTheme.buttonHeight + 24 }
            ThemedTabButton { text: qsTr("Sensors"); iconName: "chip"; iconOnly: true; width: AppTheme.buttonHeight + 24 }
            ThemedTabButton {
                text: qsTr("Users")
                iconGlyph: "\uE7EF"
                iconOnly: true
                width: AppTheme.buttonHeight + 24
                visible: AuthService.canManageUsers || AuthService.canViewAudit
            }
        }

        RowLayout {
            visible: root.settingsTabIndex === 6
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
                ThemedTabButton { text: qsTr("Basic & Modbus");   width: implicitWidth + 30 }
                ThemedTabButton { text: qsTr("Scaling & Alarms"); width: implicitWidth + 30; visible: root.sensorType === "ANALOG" }
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
                iconOnly: true
                fillColor: AppColors.error
                onClicked: root.deleteSelectedSensor()
            }

            AppButton {
                visible: root.hasSelectedSensor
                iconName: "pencil"
                iconOnly: true
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

        // Sensor Form actions (Tab 6)
        RowLayout {
            visible: root.settingsTabIndex === 6
            spacing: 8

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

        // Users: giống bảng Sensors, chỉ hiện Add khi chưa chọn dòng.
        RowLayout {
            visible: root.settingsTabIndex === 4 && root.userListActive
            spacing: 8

            AppButton {
                visible: root.hasSelectedUser
                enabled: !root.selfSelectedUser && !AuthService.busy
                iconName: "trashCan"
                iconOnly: true
                fillColor: AppColors.error
                Accessible.name: qsTr("Delete user")
                onClicked: root.deleteSelectedUser()
            }

            AppButton {
                visible: root.hasSelectedUser
                enabled: !AuthService.busy
                iconName: "pencil"
                iconOnly: true
                Accessible.name: qsTr("Edit user")
                onClicked: root.editSelectedUser()
            }

            AppButton {
                visible: !root.hasSelectedUser
                enabled: !AuthService.busy
                text: qsTr("+ Add")
                font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                Layout.preferredHeight: 44
                fillColor: AppColors.success
                onClicked: root.addUser()
            }
        }

        RowLayout {
            visible: root.settingsTabIndex === 4 && root.userFormActive
            spacing: 8

            AppButton {
                text: qsTr("Cancel")
                kind: AppButton.Neutral
                font.bold: true
                Layout.preferredHeight: 44
                enabled: !AuthService.busy
                onClicked: root.cancelUserForm()
            }

            AppButton {
                text: AuthService.busy ? qsTr("Please wait…") : qsTr("Save")
                font.pixelSize: AppTypography.labelMedium.pixelSize; font.bold: true
                Layout.preferredHeight: 44
                fillColor: AppColors.success
                enabled: !AuthService.busy
                onClicked: root.saveUserForm()
            }
        }
    }
}
