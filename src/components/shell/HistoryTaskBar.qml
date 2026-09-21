pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Item {
    id: root
    implicitHeight: 64

    function doSearch() {
        var sensorId = 0
        var idx = sensorFilter.currentIndex
        var ids = HistoryViewModel.sensorIds
        if (idx >= 0 && idx < ids.length)
            sensorId = ids[idx]
        HistoryViewModel.search(fromField.text, toField.text, sensorId)
    }

    // Filters are kept fresh in memory by main.cpp (SensorListModel::modelReset
    // → reloadFiltersFromMaps), so no DB hit on the UI thread here.
    Component.onCompleted: Qt.callLater(root.doSearch)

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
            onActivated: root.doSearch()
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

        Item { Layout.fillWidth: true }

        Label {
            text: qsTr("%1 rows").arg(HistoryViewModel.recordCount)
            color: AppColors.onSurfaceVariant
            font: AppTypography.bodyMedium
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
