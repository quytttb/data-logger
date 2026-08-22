import QtQuick
import QtQuick.Layouts
import QtGraphs
import DataLogger.Core
import DataLogger.Components
import LoggerKit.Theme
import LoggerKit.Components

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
                for (let j = 0; j < initialBuffer.length; j++)
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
                    let list = graphsView.seriesList
                    for (let i = list.length - 1; i >= 0; --i)
                        graphsView.removeSeries(list[i])
                    chartHolder.seriesMap = ({})
                }

                function rebuildSeries() {
                    clearAllSeries()

                    let sensors = MonitorController.analogSensors
                    if (!sensors || sensors.length === 0)
                        return

                    let now = Date.now()
                    chartHolder.xMin = now - trendRoot.windowMs
                    chartHolder.xMax = now
                    let yLo = Number.MAX_VALUE
                    let yHi = -Number.MAX_VALUE

                    for (let i = 0; i < sensors.length; i++) {
                        let s = sensors[i]
                        let label = s.unit && s.unit.length > 0
                                    ? (s.name + " (" + s.unit + ")")
                                    : s.name
                        let buf = MonitorController.getTrendBuffer(s.id)
                        let series = lineSeriesComponent.createObject(graphsView, {
                            seriesName: label,
                            seriesColor: s.color,
                            initialBuffer: buf
                        })
                        graphsView.addSeries(series)
                        chartHolder.seriesMap[s.id] = series

                        for (let j = 0; j < buf.length; j++) {
                            if (buf[j].y < yLo) yLo = buf[j].y
                            if (buf[j].y > yHi) yHi = buf[j].y
                        }
                    }

                    chartHolder.applyAxes(yLo, yHi)
                }

                function applyAxes(yLo, yHi) {
                    let now = Date.now()
                    let minX = now - trendRoot.windowMs
                    chartHolder.xMin = minX
                    chartHolder.xMax = now
                    xAxis.min = new Date(minX)
                    xAxis.max = new Date(now)

                    if (yLo === undefined || yLo === Number.MAX_VALUE) {
                        yLo = 0; yHi = 1
                    }
                    if (yHi <= yLo) yHi = yLo + 1
                    let margin = (yHi - yLo) * 0.1
                    if (margin === 0) margin = 1
                    chartHolder.yMin = yLo - margin
                    chartHolder.yMax = yHi + margin
                    yAxis.min = chartHolder.yMin
                    yAxis.max = chartHolder.yMax
                }

                function appendPoint(sid, x, y) {
                    let series = chartHolder.seriesMap[sid]
                    if (!series) return

                    series.append(x, y)

                    let cutoff = x - trendRoot.windowMs
                    for (let key in chartHolder.seriesMap) {
                        let s = chartHolder.seriesMap[key]
                        while (s.count > 0 && s.at(0).x < cutoff)
                            s.remove(0)
                    }

                    xAxis.min = new Date(cutoff)
                    xAxis.max = new Date(x)
                    chartHolder.xMin = cutoff
                    chartHolder.xMax = x

                    if (y < chartHolder.yMin || y > chartHolder.yMax) {
                        let lo = y, hi = y
                        for (let k in chartHolder.seriesMap) {
                            let ss = chartHolder.seriesMap[k]
                            for (let n = 0; n < ss.count; n++) {
                                let pt = ss.at(n)
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
                    visible: MonitorController.analogSensors && MonitorController.analogSensors.length > 0

                    axisX: DateTimeAxis {
                        id: xAxis
                        labelFormat: "HH:mm:ss"
                    }

                    axisY: ValueAxis {
                        id: yAxis
                        labelFormat: "%.1f"
                    }
                }

                EmptyStatePlaceholder {
                    anchors.fill: parent
                    visible: !graphsView.visible
                    message: qsTr("No active sensors.\nStart monitoring to see live trends.")
                    iconName: "showChart"
                }
            }
        }
    }
}
