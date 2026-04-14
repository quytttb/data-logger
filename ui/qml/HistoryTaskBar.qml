import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Thanh công cụ Lịch sử — nằm trong header chung (cùng chiều cao với logo).
Item {
    id: root
    implicitHeight: 64

    function todayStr() {
        return Qt.formatDate(new Date(), "dd/MM/yyyy");
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

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Label {
            text: qsTr("From:")
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        TextField {
            id: fromField
            text: todayStr()
            Layout.preferredWidth: 110
            color: Theme.textPrimary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            background: Rectangle { color: Theme.bgInput; radius: Theme.radiusSmall }
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            text: qsTr("To:")
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        TextField {
            id: toField
            text: todayStr()
            Layout.preferredWidth: 110
            color: Theme.textPrimary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            background: Rectangle { color: Theme.bgInput; radius: Theme.radiusSmall }
            Layout.alignment: Qt.AlignVCenter
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
            Layout.preferredHeight: 40
            enabled: !historyController.isLoading
            icon.source: "../../assets/icons/search.svg"
            icon.color: "white"
            icon.width: 18
            icon.height: 18
            background: Rectangle {
                color: historyController.isLoading ? "#666" : Theme.accent
                radius: 8
                opacity: parent.pressed ? 0.7 : 1.0
            }
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter
        }

        BusyIndicator {
            visible: historyController.isLoading
            running: historyController.isLoading
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Label {
            text: qsTr("%1 rows").arg(historyController.recordCount)
            color: Theme.textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            text: qsTr("CSV")
            icon.source: "../../assets/icons/export.svg"
            icon.color: "white"
            icon.width: 16
            icon.height: 16
            Layout.preferredHeight: 38
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
