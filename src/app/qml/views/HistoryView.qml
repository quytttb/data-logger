pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: histRoot
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: AppTheme.pagePadding
        spacing: AppTheme.sectionSpacing



        ElevatedPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 0
            contentSpacing: 0

            AppTableView {
                id: histTable
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: HistoryViewModel.tableModel
                loading: HistoryViewModel.isLoading
                reuseItems: true
                hasData: HistoryViewModel.tableModel.rowsSize > 0
                colWeights: [0.28, 0.22, 0.12, 0.18, 0.2]
                colMinimums: [140, 100, 60, 80, 80]
                headerAlignRight: function(col) { return col === 4 }
                emptyMessage: HistoryViewModel.lastError.length > 0
                              ? HistoryViewModel.lastError
                              : (!HistoryViewModel.searchedOnce
                                  ? qsTr("Adjust the time range or sensor, then search.")
                                  : qsTr("No records found for the selected filters."))

                delegate: ItemDelegate {
                    id: histCell
                    required property int row
                    required property int column
                    required property string recordedAt
                    required property string sensorName
                    required property string unit
                    required property string value
                    required property string rawValue

                    implicitHeight: 40
                    padding: 0
                    hoverEnabled: false

                    background: TableCellBackground {
                        cellHovered: false
                    }

                    contentItem: Label {
                        anchors {
                            left: parent.left
                            leftMargin: histCell.column === 0 ? 16 : 8
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: {
                            switch (histCell.column) {
                            case 0: return histCell.recordedAt
                            case 1: return histCell.sensorName
                            case 2: return histCell.unit
                            case 3: return histCell.value
                            case 4: return histCell.rawValue
                            default: return ""
                            }
                        }
                        horizontalAlignment: histCell.column === 4 ? Text.AlignRight : Text.AlignLeft
                        font.family: (histCell.column === 3 || histCell.column === 4) ? "monospace" : ""
                        font.weight: histCell.column === 3 ? Font.DemiBold : Font.Normal
                        color: {
                            if (histCell.column === 2) return AppColors.tableHeaderText
                            if (histCell.column === 0) return AppColors.tableCellMuted
                            if (histCell.column === 3) return AppColors.success
                            return AppColors.primaryText
                        }
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
