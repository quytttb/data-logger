import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Thanh công cụ History — nằm trong header chung (cùng chiều cao với logo).
Item {
    id: root
    implicitHeight: 64

    function formatDate(d) {
        var dd = String(d.getDate()).padStart(2, '0');
        var mm = String(d.getMonth() + 1).padStart(2, '0');
        var yyyy = d.getFullYear();
        return dd + "/" + mm + "/" + yyyy;
    }

    function doSearch() {
        var sensorId = 0;
        var idx = sensorFilter.currentIndex;
        var ids = historyController.sensorIds;
        if (idx >= 0 && idx < ids.length)
            sensorId = ids[idx];
        historyController.search(fromField.text, toField.text, sensorId);
    }

    Component.onCompleted: {
        historyController.load_sensors();
        doSearch();
    }

    // ── Date Pickers ─────────────────────────────────────────────────────
    DatePickerPopup {
        id: fromPicker
        selectedDate: new Date()
        onDatePicked: (d) => { fromField.text = root.formatDate(d) }
    }
    DatePickerPopup {
        id: toPicker
        selectedDate: new Date()
        onDatePicked: (d) => { toField.text = root.formatDate(d) }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Label {
            text: "From:"
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        TextField {
            id: fromField
            text: root.formatDate(new Date())
            readOnly: true
            Layout.preferredWidth: 110
            color: Theme.textPrimary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            background: Rectangle { color: Theme.bgInput; radius: Theme.radiusSmall }
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fromPicker.open()
            }
        }

        Label {
            text: "To:"
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        TextField {
            id: toField
            text: root.formatDate(new Date())
            readOnly: true
            Layout.preferredWidth: 110
            color: Theme.textPrimary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            background: Rectangle { color: Theme.bgInput; radius: Theme.radiusSmall }
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toPicker.open()
            }
        }

        ComboBox {
            id: sensorFilter
            Layout.preferredWidth: 160
            model: historyController.sensorNames
            currentIndex: 0
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            enabled: !historyController.isLoading && sensorModel.rowCount() > 0
            icon.source: "../../assets/icons/search.svg"
            icon.color: "white"
            icon.width: 16
            icon.height: 16
            background: Rectangle {
                color: !parent.enabled ? "#666666" : Theme.accent
                radius: 8
                opacity: parent.pressed ? 0.7 : 1.0
            }
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            id: refreshBtn
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            enabled: !historyController.isLoading && sensorModel.rowCount() > 0
            icon.source: "../../assets/icons/refresh.svg"
            icon.color: Theme.textPrimary
            icon.width: 16
            icon.height: 16
            background: Rectangle {
                color: !parent.enabled ? "#444444" : Theme.bgPanel
                border.color: Theme.borderDefault
                border.width: 1
                radius: 8
                opacity: parent.pressed ? 0.7 : 1.0
            }
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter

            RotationAnimator {
                target: refreshBtn.contentItem
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: historyController.isLoading
            }
        }

        Item { Layout.fillWidth: true }

        Label {
            text: "%1 rows".arg(historyController.recordCount)
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            text: "CSV"
            icon.source: "../../assets/icons/export.svg"
            icon.color: "white"
            icon.width: 16
            icon.height: 16
            Layout.preferredHeight: 44
            enabled: historyController.recordCount > 0
            font.pixelSize: 13
            font.bold: true
            onClicked: {
                var fname = "history_" + fromField.text.replace(/\//g, "") + "_" + toField.text.replace(/\//g, "") + ".csv";
                historyController.export_csv("/home/pi/data-logger/var/data/" + fname);
            }
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
