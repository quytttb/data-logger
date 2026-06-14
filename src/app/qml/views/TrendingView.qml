import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtGraphs
import DataLogger.Theme
import DataLogger.Core
import DataLogger.Components

Rectangle {
    id: trendRoot
    color: "transparent"

    readonly property int windowMs: 5 * 60 * 1000

    Component {
        id: lineSeriesComponent
        LineSeries {
            required property string seriesName
            required property color seriesColor
            required property var initialBuffer
            name: seriesName
            color: seriesColor
            width: 2

            Component.onCompleted: {
                if (!initialBuffer)
                    return
                for (var j = 0; j < initialBuffer.length; j++)
                    append(initialBuffer[j].x, initialBuffer[j].y)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: AppTheme.pagePadding
        spacing: 0

        ElevatedPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: AppTheme.sectionSpacing
            contentSpacing: 0

            Item {
                id: chartHolder
                Layout.fillWidth: true
                Layout.fillHeight: true

                property var seriesMap: ({})
                property real xMin: 0
                property real xMax: 0
                property real yMin: 0
                property real yMax: 1

                function clearAllSeries() {
                    var list = graphsView.seriesList
                    for (var i = list.length - 1; i >= 0; --i)
                        graphsView.removeSeries(list[i])
                    chartHolder.seriesMap = ({})
                }

                function rebuildSeries() {
                    clearAllSeries()

                    var sensors = MonitorController.analogSensors
                    if (!sensors || sensors.length === 0)
                        return

                    var now = Date.now()
                    chartHolder.xMin = now - trendRoot.windowMs
                    chartHolder.xMax = now
                    var yLo = Number.MAX_VALUE
                    var yHi = -Number.MAX_VALUE

                    for (var i = 0; i < sensors.length; i++) {
                        var s = sensors[i]
                        var label = s.unit && s.unit.length > 0
                                    ? (s.name + " (" + s.unit + ")")
                                    : s.name
                        var series = lineSeriesComponent.createObject(graphsView, {
                            seriesName: label,
                            seriesColor: s.color,
                            initialBuffer: MonitorController.getTrendBuffer(s.id)
                        })
                        graphsView.addSeries(series)
                        chartHolder.seriesMap[s.id] = series

                        var buf = MonitorController.getTrendBuffer(s.id)
                        for (var j = 0; j < buf.length; j++) {
                            if (buf[j].y < yLo) yLo = buf[j].y
                            if (buf[j].y > yHi) yHi = buf[j].y
                        }
                    }

                    chartHolder.applyAxes(yLo, yHi)
                }

                function applyAxes(yLo, yHi) {
                    var now = Date.now()
                    var minX = now - trendRoot.windowMs
                    chartHolder.xMin = minX
                    chartHolder.xMax = now
                    xAxis.min = new Date(minX)
                    xAxis.max = new Date(now)
                    xAxis.tickInterval = trendRoot.windowMs / 6

                    if (yLo === undefined || yLo === Number.MAX_VALUE) {
                        yLo = 0; yHi = 1
                    }
                    if (yHi <= yLo) yHi = yLo + 1
                    var margin = (yHi - yLo) * 0.1
                    if (margin === 0) margin = 1
                    chartHolder.yMin = yLo - margin
                    chartHolder.yMax = yHi + margin
                    yAxis.min = chartHolder.yMin
                    yAxis.max = chartHolder.yMax
                    yAxis.tickInterval = (chartHolder.yMax - chartHolder.yMin) / 7
                    if (yAxis.tickInterval <= 0)
                        yAxis.tickInterval = 1
                }

                function appendPoint(sid, x, y) {
                    var series = chartHolder.seriesMap[sid]
                    if (!series) return

                    series.append(x, y)

                    var cutoff = x - trendRoot.windowMs
                    for (var key in chartHolder.seriesMap) {
                        var s = chartHolder.seriesMap[key]
                        while (s.count > 0 && s.at(0).x < cutoff)
                            s.remove(0)
                    }

                    xAxis.min = new Date(cutoff)
                    xAxis.max = new Date(x)
                    chartHolder.xMin = cutoff
                    chartHolder.xMax = x

                    if (y < chartHolder.yMin || y > chartHolder.yMax) {
                        var lo = y, hi = y
                        for (var k in chartHolder.seriesMap) {
                            var ss = chartHolder.seriesMap[k]
                            for (var n = 0; n < ss.count; n++) {
                                var pt = ss.at(n)
                                if (pt.y < lo) lo = pt.y
                                if (pt.y > hi) hi = pt.y
                            }
                        }
                        chartHolder.applyAxes(lo, hi)
                    }
                }

                Component.onCompleted: chartHolder.rebuildSeries()

                Connections {
                    target: MonitorController
                    function onAnalogSensorsListChanged() { chartHolder.rebuildSeries() }
                    function onNewDataPoint(sid, ts, val) { chartHolder.appendPoint(sid, ts, val) }
                }

                ChartGraphsView {
                    id: graphsView
                    anchors.fill: parent

                    axisX: DateTimeAxis {
                        id: xAxis
                        labelFormat: "HH:mm:ss"
                        tickInterval: trendRoot.windowMs / 6
                    }

                    axisY: ValueAxis {
                        id: yAxis
                        labelFormat: "%.1f"
                        tickInterval: 1
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: !MonitorController.analogSensors || MonitorController.analogSensors.length === 0
                        text: qsTr("No active sensors.\nStart monitoring to see live trends.")
                        color: AppColors.onSurfaceVariant
                    font: AppTypography.bodyMedium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
