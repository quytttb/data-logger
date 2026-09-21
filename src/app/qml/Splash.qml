pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import LoggerKit.Theme

// Boot splash nhẹ cho kiosk eglfs: che màn hình trong lúc Main khởi tạo xong
// (~1s trên Pi 3). Dùng logo 4M có sẵn trong kit — không thêm asset.
// LƯU Ý eglfs: chỉ 1 OpenGL window duy nhất nên splash PHẢI là overlay trong
// Main (không dùng engine/window thứ 2 — sẽ FATAL crash).
// Tự ẩn sau 900ms kể từ lúc tạo (đủ cho first paint + startPolling).
// Chế độ shutdown (autoHide=false): hiện logo 4M + "Shutting down…" 1s
// trước khi reboot, che log systemd lúc tắt máy. C++ / QML điều khiển
// visible thủ công ở chế độ này.
Item {
    id: splashRoot
    property bool autoHide: true
    property string statusText: qsTr("Starting…")
    visible: autoHide

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

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
            running: splashRoot.visible
            implicitWidth: 40
            implicitHeight: 40
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: splashRoot.statusText
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
        }
    }

    Timer {
        interval: 900
        running: splashRoot.autoHide
        repeat: false
        onTriggered: splashRoot.visible = false
    }
}
