pragma ComponentBehavior: Bound

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

    Component {
        id: lineSeriesComponent
        LineSeries {
            required property string seriesName
            required property color seriesColor
            required property var initialBuffer
            required property bool digitalSeries
            name: seriesName
            color: seriesColor
            width: 2
            // QML lint của Qt 6.11.1 chưa expose enum QLineSeries::LineStyle;
            // giá trị 3 là StepCenter, 0 là Straight.
            lineStyle: digitalSeries ? 3 : 0

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

                    for (let i = 0; i < sensors.length; i++) {
                        let s = sensors[i]
                        let label = s.unit && s.unit.length > 0
                                    ? (s.name + " (" + s.unit + ")")
                                    : s.name
                        let buf = MonitorController.getTrendBuffer(s.id)
                        let series = lineSeriesComponent.createObject(graphsView, {
                            seriesName: label,
                            seriesColor: s.color,
                            initialBuffer: buf,
                            digitalSeries: s.sensorType === "DI" || s.sensorType === "DO"
                        })
                        graphsView.addSeries(series)
                        chartHolder.seriesMap[s.id] = series
                    }

                    chartHolder.applyTrendAxes()
                }

                function appendPoint(sid, x, y) {
                    let series = chartHolder.seriesMap[sid]
                    if (!series) return

                    series.append(x, y)

                    let cutoff = x - MonitorController.trendWindowMs
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
