#include "core/MonitorController.h"

#include <QtTest>
#include <QCoreApplication>

// Trend axis math is pure (static) so the windowing/margin/digital rules
// are locked by tests instead of living untestable in QML.
class TestTrendAxes : public QObject
{
    Q_OBJECT

private:
    using Buffers = QHash<int, std::deque<std::pair<double, double>>>;

    static Buffers buffersWith(int id, const QList<double> &values, qint64 baseMs)
    {
        Buffers b;
        std::deque<std::pair<double, double>> points;
        for (int i = 0; i < values.size(); ++i)
            points.push_back({double(baseMs + i * 1000), values[i]});
        b[id] = points;
        return b;
    }

private slots:
    void emptyBuffersDefaultRange()
    {
        Buffers b;
        QHash<int, bool> types{{1, false}};
        const auto axes = MonitorController::computeTrendAxes(1'000'000, b, types);
        QCOMPARE(axes.xMax - axes.xMin, double(MonitorController::kTrendWindowMs));
        QCOMPARE(axes.xMax, 1000000.0);
        QCOMPARE(axes.yMin, -0.1);
        QCOMPARE(axes.yMax, 1.1);
    }

    void analogMargin()
    {
        const Buffers b = buffersWith(1, {10.0, 20.0}, 900'000);
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, QHash<int, bool>{{1, false}});
        QCOMPARE(axes.yMin, 9.0);
        QCOMPARE(axes.yMax, 21.0);
    }

    void digitalOnlyForcesZeroOne()
    {
        // Even a stuck-at-1 digital line must show the 0 state.
        const Buffers b = buffersWith(7, {1.0, 1.0, 1.0}, 900'000);
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, QHash<int, bool>{{7, true}});
        QCOMPARE(axes.yMin, -0.1);
        QCOMPARE(axes.yMax, 1.1);
    }

    void mixedChartSharesRange()
    {
        Buffers b = buffersWith(1, {10.0, 20.0}, 900'000);
        b[2] = buffersWith(2, {0.0, 1.0}, 900'000)[2];
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, QHash<int, bool>{{1, false}, {2, true}});
        QCOMPARE(axes.yMin, -2.0);
        QCOMPARE(axes.yMax, 22.0);
    }

    void windowConstants()
    {
        QCOMPARE(MonitorController::kTrendWindowMs, qint64(5 * 60 * 1000));
        QCOMPARE(MonitorController::kTrendTickCount, 6);
    }

    void filterSelectsSubset()
    {
        // Sensor 1 ~1000, sensor 2 ~30-40: chỉ chọn sensor 2 thì Y phải
        // co lại theo sensor 2 (margin 10% của 30..40).
        Buffers b = buffersWith(1, {990.0, 1010.0}, 900'000);
        b[2] = buffersWith(2, {30.0, 40.0}, 900'000)[2];
        QHash<int, bool> types{{1, false}, {2, false}};
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, types, QSet<int>{2});
        QCOMPARE(axes.yMin, 29.0);
        QCOMPARE(axes.yMax, 41.0);
    }

    void filterEmptyBehavesLikeAll()
    {
        Buffers b = buffersWith(1, {990.0, 1010.0}, 900'000);
        b[2] = buffersWith(2, {30.0, 40.0}, 900'000)[2];
        QHash<int, bool> types{{1, false}, {2, false}};
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, types, QSet<int>{});
        // margin 10% của 30..1010 = 98
        QCOMPARE(axes.yMin, -68.0);
        QCOMPARE(axes.yMax, 1108.0);
    }

    void filterUnknownIdFallsBackToDefault()
    {
        Buffers b = buffersWith(1, {10.0, 20.0}, 900'000);
        const auto axes = MonitorController::computeTrendAxes(
            1'000'000, b, QHash<int, bool>{{1, false}}, QSet<int>{999});
        QCOMPARE(axes.yMin, -0.1);
        QCOMPARE(axes.yMax, 1.1);
    }
};

QTEST_MAIN(TestTrendAxes)
#include "trend_axes_test.moc"
