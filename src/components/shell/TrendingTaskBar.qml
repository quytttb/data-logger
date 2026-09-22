pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DataLogger.Core
import LoggerKit.Theme

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

        // Nút icon filter (glyph filter_alt trong font Material Symbols
        // bundle sẵn — không thêm icon vào kit dùng chung).
        Button {
            id: filterButton
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            onClicked: filterPopup.open()

            background: Rectangle {
                radius: AppTheme.chipRadius
                color: root.isFiltered ? AppColors.withAlpha(AppColors.primaryColor, 0.25)
                                       : AppColors.surfaceContainerHigh
                border.width: root.isFiltered ? 1 : 0
                border.color: AppColors.primaryColor
            }

            contentItem: Text {
                text: "\uEF4B" // filter_alt (Material Symbols Outlined)
                font.family: "Material Symbols Outlined"
                font.pixelSize: 26
                color: root.isFiltered ? AppColors.primaryColor : AppColors.onSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
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
                spacing: 24

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

    // Popup checklist multi-select (kiosk touch: mỗi hàng cao 48).
    Popup {
        id: filterPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 16
        modal: true
        focus: true

        background: Rectangle {
            color: AppColors.surfaceContainerHigh
            radius: AppTheme.cardRadius
            border.width: 1
            border.color: AppColors.elevatedBorder
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Show sensors")
                    color: AppColors.primaryText
                    font.pixelSize: AppTypography.titleSmall.pixelSize
                    font.bold: true
                    Layout.fillWidth: true
                }
                Button {
                    text: qsTr("All")
                    font.pixelSize: AppTypography.bodyMedium.pixelSize
                    onClicked: root.selectAll()
                }
            }

            Text {
                text: qsTr("Uncheck all = show all. At least one stays on.")
                color: AppColors.onSurfaceVariant
                font.pixelSize: AppTypography.bodySmall.pixelSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: MonitorController.analogSensors

                delegate: RowLayout {
                    id: checkRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 10
                    required property var modelData

                    Rectangle {
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: width / 2
                        color: checkRow.modelData.color
                        Layout.alignment: Qt.AlignVCenter
                    }

                    CheckBox {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: checkRow.modelData.unit && checkRow.modelData.unit.length > 0
                              ? (checkRow.modelData.name + " (" + checkRow.modelData.unit + ")")
                              : checkRow.modelData.name
                        font.pixelSize: AppTypography.bodyMedium.pixelSize
                        checked: root.selectedIds.length === 0
                                 || root.selectedIds.indexOf(checkRow.modelData.id) >= 0
                        onToggled: root.setChecked(checkRow.modelData.id, checked)
                    }
                }
            }

            Button {
                text: qsTr("Done")
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.topMargin: 8
                font.pixelSize: AppTypography.bodyMedium.pixelSize
                font.bold: true
                highlighted: true
                onClicked: filterPopup.close()
            }
        }
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
