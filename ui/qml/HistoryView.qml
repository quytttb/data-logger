import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts
import "."

Rectangle {
    id: histRoot
    color: "transparent"

    readonly property var chartColors: Theme.chartSeriesColors

    // ── Popup lỗi / thông báo chung (tìm kiếm, v.v.) ─────────────────────
    Popup {
        id: histPopup
        anchors.centerIn: parent
        width: Math.min(440, histRoot.width - 32)
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: Theme.bgPanel
            radius: Theme.radiusCard
            border.color: Theme.accent
            border.width: 1
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            Text {
                id: histPopTitle
                font.bold: true
                font.pixelSize: 17
                color: Theme.textPrimary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            Text {
                id: histPopMsg
                wrapMode: Text.WordWrap
                color: Theme.accentText
                font.pixelSize: 14
                Layout.fillWidth: true
                Layout.maximumWidth: parent.width
                horizontalAlignment: Text.AlignLeft
            }
            Button {
                text: "Close"
                Layout.alignment: Qt.AlignHCenter
                onClicked: histPopup.close()
            }
        }
    }

    Connections {
        target: historyController
        function onMessageSent(t, m) {
            histPopTitle.text = t;
            histPopMsg.text = m;
            histPopup.open();
        }
    }

    // ── Chart data refresh ────────────────────────────────────────────────
    Connections {
        target: historyController
        function onChartDataChanged() {
            if (viewStack.currentIndex === 1)
                histRoot.refreshChart();
        }
    }

    function refreshChart() {
        chartView.removeAllSeries();

        var data = historyController.chartData;
        if (!data || data.length === 0) return;

        var xMin = Number.MAX_VALUE, xMax = -Number.MAX_VALUE;
        var yMin = Number.MAX_VALUE, yMax = -Number.MAX_VALUE;

        for (var i = 0; i < data.length; i++) {
            var series = chartView.createSeries(
                ChartView.SeriesTypeLine, data[i].name, axisX, axisY
            );
            series.color = chartColors[i % chartColors.length];
            series.width = 2;
            series.pointsVisible = (data[i].points.length <= 60);

            var points = data[i].points;
            for (var j = 0; j < points.length; j++) {
                series.append(points[j].x, points[j].y);
                xMin = Math.min(xMin, points[j].x);
                xMax = Math.max(xMax, points[j].x);
                yMin = Math.min(yMin, points[j].y);
                yMax = Math.max(yMax, points[j].y);
            }
        }

        if (xMin < xMax) {
            axisX.min = new Date(xMin);
            axisX.max = new Date(xMax);
        }
        if (yMin <= yMax) {
            var margin = (yMax - yMin) * 0.1;
            if (margin === 0) margin = 1;
            axisY.min = yMin - margin;
            axisY.max = yMax + margin;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // ── View toggle: List / Chart ─────────────────────────────────────
        TabBar {
            id: viewTabBar
            Layout.alignment: Qt.AlignLeft
            currentIndex: viewStack.currentIndex

            TabButton { 
                text: "List"
                icon.source: "../../assets/icons/list.svg"
                width: implicitWidth + 60
                onClicked: viewStack.currentIndex = 0
            }
            TabButton { 
                text: "Chart"
                icon.source: "../../assets/icons/chart.svg"
                width: implicitWidth + 60
                onClicked: {
                    viewStack.currentIndex = 1;
                    histRoot.refreshChart();
                }
            }
        }

        // ── Content stack ─────────────────────────────────────────────────
        StackLayout {
            id: viewStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // ═══ Tab 0: List ══════════════════════════════════════════════
            ColumnLayout {
                spacing: 0

                // Table header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Theme.bgSeparator
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Label { text: "Time";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 160 }
                        Label { text: "Sensor";    color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 150 }
                        Label { text: "Unit";      color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 80 }
                        Label { text: "Value";     color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.preferredWidth: 120 }
                        Label { text: "Raw value"; color: Theme.accent; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                    }
                }

                // Data rows
                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: historyModel
                    clip: true
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: historyList.width
                        height: 40
                        color: index % 2 === 0 ? Theme.bgPanel : Theme.bgStripe
                        radius: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            Text { text: model.recordedAt;  color: Theme.textPrimary;   font.pixelSize: 13; Layout.preferredWidth: 160 }
                            Text { text: model.sensorName;  color: Theme.accentText;    font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 150; elide: Text.ElideRight }
                            Text { text: model.unit;        color: Theme.textSecondary; font.pixelSize: 13; Layout.preferredWidth: 80 }
                            Text { text: model.value;       color: Theme.statusOk;      font.pixelSize: 14; font.bold: true; font.family: "Monospace"; Layout.preferredWidth: 120 }
                            Text { text: model.rawValue;    color: Theme.textSecondary; font.pixelSize: 13; Layout.fillWidth: true }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: historyList.count === 0 && !historyController.isLoading
                        text: "No data.\nAdjust the time range or sensor, then search."
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: Math.min(400, parent.width - 32)
                    }
                }
            }

            // ═══ Tab 1: Chart ═════════════════════════════════════════════
            Item {
                ChartView {
                    id: chartView
                    anchors.fill: parent
                    backgroundColor: Theme.bgPanel
                    plotAreaColor: Theme.bgDeep
                    antialiasing: true

                    legend.visible: true
                    legend.alignment: Qt.AlignBottom
                    legend.labelColor: Theme.textSecondary
                    legend.font.pixelSize: 12
                    legend.font.bold: true

                    DateTimeAxis {
                        id: axisX
                        format: "dd/MM HH:mm"
                        labelsColor: Theme.textSecondary
                        gridLineColor: Theme.bgSeparator
                        color: Theme.bgSeparator
                        labelsFont.pixelSize: 11
                        tickCount: 6
                    }

                    ValueAxis {
                        id: axisY
                        labelsColor: Theme.textSecondary
                        gridLineColor: Theme.bgSeparator
                        color: Theme.bgSeparator
                        labelsFont.pixelSize: 11
                    }
                }

                // Empty state overlay
                Label {
                    anchors.centerIn: parent
                    visible: historyController.recordCount === 0 && !historyController.isLoading
                    text: "No data.\nSearch first to display the chart."
                    color: Theme.textSecondary
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
