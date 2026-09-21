pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import LoggerKit.Theme

// Boot splash nhẹ cho kiosk eglfs: che màn hình đen trong lúc engine biên dịch
// Main.qml (~1-2s trên Pi 3). Dùng logo 4M có sẵn trong kit — không thêm asset.
// C++ (main.cpp) đóng splash sau khi cửa sổ Main hiện + 800ms.
Window {
    id: splashRoot
    width: 1024
    height: 600
    visibility: Window.FullScreen
    flags: Qt.SplashScreen | Qt.WindowStaysOnTopHint
    color: "#000000"
    title: "Data Logger"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/qt/qml/LoggerKit/Components/resources/icons/brand_4m_technologies_blue.svg"
            sourceSize: Qt.size(160, 160)
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DATA LOGGER"
            color: "#FFFFFF"
            font: AppTypography.titleLarge
        }

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: true
            implicitWidth: 40
            implicitHeight: 40
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Starting…")
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
        }
    }
}
