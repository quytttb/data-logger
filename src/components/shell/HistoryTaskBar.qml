import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

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
            color: Theme.textSecondary
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
            color: Theme.textSecondary
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
            model: HistoryViewModel.sensorNames
            currentIndex: 0
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            id: searchBtn
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            enabled: !HistoryViewModel.isLoading && SensorListModel.count > 0
            icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/search.svg"
            icon.color: AppColors.buttonIconOnFilled
            icon.width: 16
            icon.height: 16
            background: Rectangle {
                color: !searchBtn.enabled ? Theme.btnBgDisabled : Theme.accent
                radius: Theme.radiusMedium
                opacity: searchBtn.pressed ? 0.7 : 1.0
            }
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            id: refreshBtn
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            enabled: !HistoryViewModel.isLoading && SensorListModel.count > 0
            icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/refresh.svg"
            icon.color: AppColors.buttonIcon
            icon.width: 16
            icon.height: 16
            background: Rectangle {
                color: !refreshBtn.enabled ? Theme.btnBgMuted : Theme.bgPanel
                border.color: Theme.borderDefault
                border.width: 1
                radius: Theme.radiusMedium
                opacity: refreshBtn.pressed ? 0.7 : 1.0
            }
            onClicked: root.doSearch()
            Layout.alignment: Qt.AlignVCenter

            RotationAnimator {
                target: refreshBtn.contentItem
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: HistoryViewModel.isLoading
            }
        }

        Button {
            id: exportBtn
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            enabled: HistoryViewModel.recordCount > 0
            icon.source: "qrc:/qt/qml/DataLogger/Components/resources/icons/export.svg"
            icon.color: AppColors.buttonIcon
            icon.width: 16
            icon.height: 16
            background: Rectangle {
                color: !exportBtn.enabled ? Theme.btnBgMuted : Theme.bgPanel
                border.color: Theme.borderDefault
                border.width: 1
                radius: Theme.radiusMedium
                opacity: exportBtn.pressed ? 0.7 : 1.0
            }
            onClicked: csvSaveDialog.open()
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Label {
            text: qsTr("%1 rows").arg(HistoryViewModel.recordCount)
            color: Theme.textSecondary
            font: AppTypography.bodyMedium
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
