pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    implicitHeight: 64

    FileDialog {
        id: csvSaveDialog
        title: qsTr("Export CSV")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("CSV files (*.csv)"), qsTr("All files (*)")]
        defaultSuffix: "csv"
        onAccepted: HistoryViewModel.exportCsv(selectedFile)
    }

    Connections {
        target: HistoryViewModel
        function onExportFinished(ok, message) {
            if (ok) {
                AppNotifier.show(qsTr("CSV exported: %1").arg(message), "success")
            } else {
                AppNotifier.show(qsTr("CSV export failed"), "error",
                                 { detailText: message, detailTitle: qsTr("Export error") })
            }
        }
    }

    function doSearch() {
        var sensorId = 0
        var idx = sensorFilter.currentIndex
        var ids = HistoryViewModel.sensorIds
        if (idx >= 0 && idx < ids.length)
            sensorId = ids[idx]
        HistoryViewModel.search(fromField.text, toField.text, sensorId)
    }

    Component.onCompleted: {
        HistoryViewModel.load_sensors()
        Qt.callLater(root.doSearch)
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Label {
            text: qsTr("From:")
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
            Layout.alignment: Qt.AlignVCenter
        }

        DateField {
            id: fromField
            Layout.preferredWidth: 118
            Layout.preferredHeight: 40
            initialDate: {
                const d = new Date()
                d.setDate(d.getDate() - 7)
                return d
            }
        }

        Label {
            text: qsTr("To:")
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
            Layout.alignment: Qt.AlignVCenter
        }

        DateField {
            id: toField
            Layout.preferredWidth: 118
            Layout.preferredHeight: 40
            initialDate: new Date()
        }

        ComboBox {
            id: sensorFilter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 40
            model: HistoryViewModel.sensorNames
            currentIndex: 0
            Layout.alignment: Qt.AlignVCenter
        }

        AppButton {
            iconName: "magnify"
            enabled: !HistoryViewModel.isLoading && SensorListModel.count > 0
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter
        }

        AppButton {
            iconName: "refresh"
            iconSpinning: HistoryViewModel.isLoading
            enabled: !HistoryViewModel.isLoading && SensorListModel.count > 0
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter
        }

        AppButton {
            iconName: "download"
            enabled: HistoryViewModel.recordCount > 0
            onClicked: csvSaveDialog.open()
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Label {
            text: qsTr("%1 rows").arg(HistoryViewModel.recordCount)
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
