import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts
import ".."

Rectangle {
    id: trendRoot
    color: "transparent"

    // Visible window of live data — points older than this scroll off the chart.
    readonly property int windowMs: 5 * 60 * 1000

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 0

        // ── Card container (matches Settings form style) ─────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bgPanel
            radius: Theme.radiusCard
            border.color: Theme.borderDefault
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 0

                // Legend lives in MainHeaderChrome (TrendingTaskBar.qml)

                Item {
                    id: chartHolder
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property var seriesMap: ({})
                    property real combinedXMin: 0
                    property real combinedXMax: 0
                    property real combinedYMin: 0
                    property real combinedYMax: 1

                    function rebuildSeries() {
                        combinedChart.removeAllSeries()
                        chartHolder.seriesMap = ({})

                        var sensors = monitorController.analogSensors
                        if (!sensors || sensors.length === 0)
                            return

                        var now = Date.now()
                        chartHolder.combinedXMin = now - trendRoot.windowMs
                        chartHolder.combinedXMax = now
                        var yLo = Number.MAX_VALUE
                        var yHi = -Number.MAX_VALUE

                        for (var i = 0; i < sensors.length; i++) {
                            var s = sensors[i]
                            var label = s.unit && s.unit.length > 0
                                        ? (s.name + " (" + s.unit + ")")
                                        : s.name
                            var series = combinedChart.createSeries(
                                ChartView.SeriesTypeLine, label, combinedAxisX, combinedAxisY)
                            series.color = s.color
                            series.width = 2
                            chartHolder.seriesMap[s.id] = series

                            var buf = monitorController.getTrendBuffer(s.id)
                            for (var j = 0; j < buf.length; j++) {
                                series.append(buf[j].x, buf[j].y)
                                if (buf[j].x < chartHolder.combinedXMin) chartHolder.combinedXMin = buf[j].x
                                if (buf[j].x > chartHolder.combinedXMax) chartHolder.combinedXMax = buf[j].x
                                if (buf[j].y < yLo) yLo = buf[j].y
                                if (buf[j].y > yHi) yHi = buf[j].y
                            }
                        }

                        chartHolder.applyAxes(yLo, yHi)
                    }

                    function applyAxes(yLo, yHi) {
                        var minX = chartHolder.combinedXMax - trendRoot.windowMs
                        if (chartHolder.combinedXMin < minX) chartHolder.combinedXMin = minX
                        if (chartHolder.combinedXMax <= chartHolder.combinedXMin)
                            chartHolder.combinedXMax = chartHolder.combinedXMin + 1000
                        combinedAxisX.min = new Date(chartHolder.combinedXMin)
                        combinedAxisX.max = new Date(chartHolder.combinedXMax)

                        if (yLo === undefined || yLo === Number.MAX_VALUE) {
                            yLo = 0; yHi = 1
                        }
                        if (yHi <= yLo) yHi = yLo + 1
                        var margin = (yHi - yLo) * 0.1
                        if (margin === 0) margin = 1
                        chartHolder.combinedYMin = yLo - margin
                        chartHolder.combinedYMax = yHi + margin
                        combinedAxisY.min = chartHolder.combinedYMin
                        combinedAxisY.max = chartHolder.combinedYMax
                    }

                    function appendPoint(sid, x, y) {
                        var series = chartHolder.seriesMap[sid]
                        if (!series)
                            return
                        series.append(x, y)

                        var cutoff = x - trendRoot.windowMs
                        for (var key in chartHolder.seriesMap) {
                            var s = chartHolder.seriesMap[key]
                            while (s.count > 0 && s.at(0).x < cutoff)
                                s.remove(0)
                        }

                        chartHolder.combinedXMax = x
                        chartHolder.combinedXMin = cutoff
                        combinedAxisX.min = new Date(chartHolder.combinedXMin)
                        combinedAxisX.max = new Date(chartHolder.combinedXMax)

                        if (y < chartHolder.combinedYMin || y > chartHolder.combinedYMax) {
                            var lo = y, hi = y
                            for (var k in chartHolder.seriesMap) {
                                var ss = chartHolder.seriesMap[k]
                                for (var n = 0; n < ss.count; n++) {
                                    var yy = ss.at(n).y
                                    if (yy < lo) lo = yy
                                    if (yy > hi) hi = yy
                                }
                            }
                            chartHolder.applyAxes(lo, hi)
                        }
                    }

                    Component.onCompleted: chartHolder.rebuildSeries()

                    Connections {
                        target: monitorController
                        function onAnalogSensorsListChanged() { chartHolder.rebuildSeries() }
                        function onNewDataPoint(sid, ts, val) { chartHolder.appendPoint(sid, ts, val) }
                    }

                    ChartView {
                        id: combinedChart
                        anchors.fill: parent
                        backgroundColor: Theme.bgPanel
                        plotAreaColor: Theme.bgDeep
                        antialiasing: true
                        legend.visible: false
                        margins.top: 4
                        margins.bottom: 4
                        margins.left: 4
                        margins.right: 4

                        DateTimeAxis {
                            id: combinedAxisX
                            format: "HH:mm:ss"
                            labelsColor: Theme.textSecondary
                            gridLineColor: Theme.bgSeparator
                            color: Theme.bgSeparator
                            labelsFont.pixelSize: 11
                            tickCount: 6
                        }

                        ValueAxis {
                            id: combinedAxisY
                            tickCount: 7
                            labelFormat: "%.1f"
                            labelsColor: Theme.textSecondary
                            gridLineColor: Theme.bgSeparator
                            color: Theme.bgSeparator
                            labelsFont.pixelSize: 11
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: !monitorController.analogSensors || monitorController.analogSensors.length === 0
                        text: "No active sensors.\nStart monitoring to see live trends."
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
