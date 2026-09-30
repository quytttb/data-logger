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

    readonly property bool hasSensors: MonitorController.analogSensors
                                       && MonitorController.analogSensors.length > 0

    // id sensor đang chọn (rỗng = tất cả). Khởi tạo full khi danh sách đổi.
    property var selectedIds: []

    // Sensor hiển thị trên legend/graph (rỗng = tất cả).
    readonly property var visibleSensors: {
        let list = MonitorController.analogSensors
        if (!list) return []
        if (root.selectedIds.length === 0) return list
        return list.filter(function(s) { return root.selectedIds.indexOf(s.id) >= 0 })
    }

    // Có đang lọc (chọn thiếu sensor) — icon filter đổi màu + hiện đếm.
    readonly property bool isFiltered: {
        let all = root.allIds().length
        let sel = root.selectedIds.length
        return sel > 0 && sel < all
    }

    function allIds() {
        let ids = []
        let list = MonitorController.analogSensors
        if (!list) return ids
        for (let i = 0; i < list.length; ++i) ids.push(list[i].id)
        return ids
    }

    function setChecked(sid, on) {
        let cur = root.selectedIds.slice()
        let at = cur.indexOf(sid)
        if (on && at < 0) cur.push(sid)
        if (!on && at >= 0) {
            if (cur.length <= 1) return // giữ ít nhất 1 sensor được chọn
            cur.splice(at, 1)
        }
        root.selectedIds = cur
        MonitorController.setTrendingSelectedIds(cur)
    }

    function selectAll() {
        root.selectedIds = root.allIds()
        MonitorController.setTrendingSelectedIds(root.selectedIds)
    }

    function syncFromSensors() {
        // Danh sách sensor đổi (thêm/xóa): reset về chọn tất cả.
        root.selectedIds = root.allIds()
        MonitorController.setTrendingSelectedIds([])
    }

    Component.onCompleted: root.syncFromSensors()

    Connections {
        target: MonitorController
        function onAnalogSensorsListChanged() { root.syncFromSensors() }
        function onTrendingFilterChanged() {
            // Controller có thể cắt id đã xóa — đồng bộ lại checkbox.
            let ids = MonitorController.trendingSelectedIds
            if (ids && ids.length > 0) root.selectedIds = ids.slice()
            else root.selectedIds = root.allIds()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 12
        visible: root.hasSensors

        // Nút filter dùng AppButton kit (icon filterAlt) — Tonal khi đang
        // lọc, Neutral khi xem tất cả. Đếm n/m hiện bên cạnh khi lọc.
        AppButton {
            id: filterButton
            Layout.alignment: Qt.AlignVCenter
            kind: root.isFiltered ? AppButton.Primary : AppButton.Tonal
            iconName: "filterAlt"
            iconOnly: true
            iconSide: 24
            tooltipText: qsTr("Filter sensors")
            onClicked: filterDialog.open()
        }

        Text {
            visible: root.isFiltered
            Layout.alignment: Qt.AlignVCenter
            text: qsTr("%1/%2").arg(root.selectedIds.length).arg(root.allIds().length)
            color: AppColors.primaryColor
            font.pixelSize: AppTypography.bodyMedium.pixelSize
            font.bold: true
        }

        Item {
            id: legendArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flow {
                id: legendFlow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Math.min(implicitHeight, 48)
                spacing: 8

                Repeater {
                    id: legendRepeater
                    model: root.visibleSensors

                    delegate: Row {
                        id: chip
                        spacing: 8
                        height: 20
                        required property var modelData

                        Rectangle {
                            width: 12
                            height: 12
                            radius: width / 2
                            color: chip.modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.unit && chip.modelData.unit.length > 0
                                  ? (chip.modelData.name + " (" + chip.modelData.unit + ")")
                                  : chip.modelData.name
                            color: AppColors.primaryText
                            font.pixelSize: AppTypography.bodySmall.pixelSize
                            font.bold: true
                        }
                    }
                }
            }

            // The header fits two legend rows. Mask a third row with an explicit
            // ellipsis instead of allowing the title bar to grow or scroll.
            Rectangle {
                id: overflowMask
                visible: legendFlow.implicitHeight > 48
                anchors.right: parent.right
                anchors.bottom: legendFlow.bottom
                width: overflowText.implicitWidth + 12
                height: 20
                color: AppColors.surface

                Text {
                    id: overflowText
                    anchors.centerIn: parent
                    text: "..."
                    color: AppColors.primaryText
                    font.pixelSize: AppTypography.bodySmall.pixelSize
                    font.bold: true
                }
            }
        }
    }

    // Dialog lọc kit (chọn cảm biến + khoảng lịch sử) — thay Popup custom cũ.
    TrendingFilterDialog {
        id: filterDialog
        parent: Overlay.overlay
        taskBar: root
    }

    Text {
        anchors.fill: parent
        visible: !root.hasSensors
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No active sensors")
        color: AppColors.onSurfaceVariant
        font.pixelSize: AppTypography.bodySmall.pixelSize
        font.italic: true
    }
}
