pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtGraphs
import DataLogger.Core
import LoggerKit.Theme
import LoggerKit.Components

Rectangle {
    id: trendRoot
    color: "transparent"

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

                // Axis ranges are computed in C++ (MonitorController trend
                // properties) — QML only applies them to the axes here.
                function applyTrendAxes() {
                    xAxis.min = new Date(MonitorController.trendXMin)
                    xAxis.max = new Date(MonitorController.trendXMax)
                    yAxis.min = MonitorController.trendYMin
                    yAxis.max = MonitorController.trendYMax
                }

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

                    // Multi-select filter (rỗng = tất cả). Trục Y đã được C++
                    // adapt theo đúng tập này (updateTrendAxes + filter).
                    let sel = MonitorController.trendingSelectedIds
                    let useFilter = sel && sel.length > 0

                    for (let i = 0; i < sensors.length; i++) {
                        let s = sensors[i]
                        if (useFilter && sel.indexOf(s.id) < 0)
                            continue
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
                    }

                    chartHolder.applyTrendAxes()
                }

                function appendPoint(sid, x, y) {
                    // Bỏ điểm của sensor đã bị filter-out (buffer C++ vẫn giữ).
                    let sel = MonitorController.trendingSelectedIds
                    if (sel && sel.length > 0 && sel.indexOf(sid) < 0)
                        return
                    let series = chartHolder.seriesMap[sid]
                    if (!series) return

                    series.append(x, y)

                    // Trim horizon comes from the C++ trend buffers
                    // (MonitorController.trendXMin) — QML never recomputes the
                    // trendWindowMs math itself.
                    let cutoff = MonitorController.trendXMin
                    for (let key in chartHolder.seriesMap) {
                        let s = chartHolder.seriesMap[key]
                        while (s.count > 0 && s.at(0).x < cutoff)
                            s.remove(0)
                    }
                }

                Component.onCompleted: chartHolder.rebuildSeries()

                Connections {
                    target: MonitorController
                    function onAnalogSensorsListChanged() { chartHolder.rebuildSeries() }
                    function onNewDataPoint(sid, ts, val) { chartHolder.appendPoint(sid, ts, val) }
                    function onTrendAxesChanged() { chartHolder.applyTrendAxes() }
                    function onTrendingFilterChanged() { chartHolder.rebuildSeries() }
                }

                ChartGraphsView {
                    id: graphsView
                    anchors.fill: parent
                    visible: MonitorController.analogSensors && MonitorController.analogSensors.length > 0
                    timezoneId: SettingsController ? SettingsController.timezone : AppDefaults.timezone

                    axisX: DateTimeAxis {
                        id: xAxis
                        labelFormat: "HH:mm:ss"
                        tickInterval: MonitorController.trendTickCount
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
