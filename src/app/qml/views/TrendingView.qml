pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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

                // Series đã gỡ khỏi graph, chờ hủy ở lần rebuild sau.
                // KHÔNG destroy() ngay sau removeSeries: QGraphsView còn
                // polish pending trỏ tới series cũ → use-after-free (SEGV
                // trong PointRenderer::afterPolish, core 18:54 Pi).
                property var deadSeries: []

                // live = realtime 5 phút (MonitorController), history = query
                // khoảng đã chọn (TrendingHistoryViewModel, đã downsample).
                readonly property bool showHistory: TrendingHistoryViewModel.hasHistory

                // Axis ranges are computed in C++ — QML only applies them here.
                function applyTrendAxes() {
                    if (chartHolder.showHistory) {
                        xAxis.min = new Date(TrendingHistoryViewModel.historyXMin)
                        xAxis.max = new Date(TrendingHistoryViewModel.historyXMax)
                        yAxis.min = TrendingHistoryViewModel.historyYMin
                        yAxis.max = TrendingHistoryViewModel.historyYMax
                        // Nhãn trục X theo độ dài khoảng: ≤1h giây, ≤1d giờ,
                        // dài hơn thì ngày + giờ.
                        const range = TrendingHistoryViewModel.historyXMax
                                    - TrendingHistoryViewModel.historyXMin
                        xAxis.labelFormat = range <= 3600000 ? "HH:mm:ss"
                            : (range <= 86400000 ? "HH:mm" : "dd/MM HH:mm")
                    } else {
                        xAxis.min = new Date(MonitorController.trendXMin)
                        xAxis.max = new Date(MonitorController.trendXMax)
                        yAxis.min = MonitorController.trendYMin
                        yAxis.max = MonitorController.trendYMax
                        xAxis.labelFormat = "HH:mm:ss"
                    }
                }

                function clearAllSeries() {
                    // Hủy đợt trước (đã detach từ rebuild trước, không còn
                    // polish nào chạm tới nên an toàn).
                    for (let i = 0; i < chartHolder.deadSeries.length; ++i) {
                        let d = chartHolder.deadSeries[i]
                        if (d) d.destroy()
                    }
                    chartHolder.deadSeries = []
                    // Duyệt seriesMap do mình quản lý (không dùng
                    // graphsView.seriesList — có thể chứa entry undefined).
                    for (let key in chartHolder.seriesMap) {
                        let s = chartHolder.seriesMap[key]
                        if (!s)
                            continue
                        graphsView.removeSeries(s)
                        chartHolder.deadSeries.push(s)
                    }
                    chartHolder.seriesMap = ({})
                }

                function rebuildSeries() {
                    clearAllSeries()

                    let sensors = MonitorController.analogSensors
                    if (!sensors || sensors.length === 0)
                        return

                    // Multi-select filter (rỗng = tất cả). Live: trục Y đã được
                    // C++ adapt theo đúng tập này; history: query đúng tập này.
                    let sel = MonitorController.trendingSelectedIds
                    let useFilter = sel && sel.length > 0

                    // History: buffer bulk đã downsample (~800 điểm), nạp 1 lần.
                    let histPoints = chartHolder.showHistory
                                     ? TrendingHistoryViewModel.seriesPoints : null

                    for (let i = 0; i < sensors.length; i++) {
                        let s = sensors[i]
                        if (useFilter && sel.indexOf(s.id) < 0)
                            continue
                        let label = s.unit && s.unit.length > 0
                                    ? (s.name + " (" + s.unit + ")")
                                    : s.name
                        let buf = histPoints ? (histPoints[String(s.id)] || [])
                                             : MonitorController.getTrendBuffer(s.id)
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
                    // History mode: điểm live không vẽ (đang xem quá khứ).
                    if (chartHolder.showHistory)
                        return
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
                    function onTrendAxesChanged() {
                        if (!chartHolder.showHistory) chartHolder.applyTrendAxes()
                    }
                    function onTrendingFilterChanged() { chartHolder.rebuildSeries() }
                }

                Connections {
                    target: TrendingHistoryViewModel
                    function onHistoryChanged() { chartHolder.rebuildSeries() }
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

                // Overlay khi đang query lịch sử (worker thread).
                BusyIndicator {
                    anchors.centerIn: parent
                    running: visible
                    visible: TrendingHistoryViewModel.loading
                }

                // Banner khi cửa sổ vượt trần dòng — graph chỉ hiện điểm cũ nhất.
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8
                    visible: chartHolder.showHistory && TrendingHistoryViewModel.historyTruncated
                    radius: 4
                    color: AppColors.warningContainer
                    width: warnText.implicitWidth + 16
                    height: warnText.implicitHeight + 8

                    Text {
                        id: warnText
                        anchors.centerIn: parent
                        text: qsTr("Range too large — oldest points only")
                        color: AppColors.primaryText
                        font.pixelSize: AppTypography.labelSmall.pixelSize
                    }
                }
            }
        }
    }
}
