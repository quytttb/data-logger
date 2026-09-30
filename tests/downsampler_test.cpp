#include "utils/chart/Downsampler.h"

#include <QtTest>

// Min-max bucket phải giữ envelope/đỉnh/alarm và thứ tự thời gian,
// đầu/cuối luôn tồn tại, output bị chặn ở ~maxPoints.
class TestDownsampler : public QObject
{
    Q_OBJECT

    static QVector<TrendPoint> sineWithSpike(int n, int spikeIdx, double spikeVal)
    {
        QVector<TrendPoint> pts;
        pts.reserve(n);
        for (int i = 0; i < n; ++i) {
            double y = 10.0 + 5.0 * qSin(i * 0.1);
            if (i == spikeIdx)
                y = spikeVal;
            pts.append({double(i * 1000), y});
        }
        return pts;
    }

private slots:
    void emptyPassthrough()
    {
        QVERIFY(Downsampler::minMax({}, 800).isEmpty());
    }

    void smallInputUntouched()
    {
        const auto in = sineWithSpike(100, -1, 0.0);
        const auto out = Downsampler::minMax(in, 800);
        QCOMPARE(out.size(), 100);
        QCOMPARE(out.first().x, in.first().x);
        QCOMPARE(out.last().x, in.last().x);
    }

    void spikePreserved()
    {
        // Đỉnh nhọn 1 mẫu giữa 5000 điểm phải sống sót sau downsample.
        const auto in = sineWithSpike(5000, 2500, 999.0);
        const auto out = Downsampler::minMax(in, 800);
        QVERIFY(out.size() <= 802);
        bool found = false;
        for (const auto &p : out) {
            if (qFuzzyCompare(p.y, 999.0)) {
                found = true;
                QCOMPARE(p.x, 2500000.0);
            }
        }
        QVERIFY2(found, "single-sample spike must survive min-max downsampling");
    }

    void firstLastKeptAndOrdered()
    {
        const auto in = sineWithSpike(3000, -1, 0.0);
        const auto out = Downsampler::minMax(in, 800);
        QCOMPARE(out.first().x, in.first().x);
        QCOMPARE(out.last().x, in.last().x);
        for (int i = 1; i < out.size(); ++i)
            QVERIFY2(out[i].x > out[i - 1].x, "output must stay time-ordered");
    }

    void alarmAnchored()
    {
        // Điểm alarm nằm trong vùng phẳng vẫn phải xuất hiện.
        QVector<TrendPoint> in;
        QVector<char> alarm;
        for (int i = 0; i < 2000; ++i) {
            in.append({double(i * 1000), 20.0});
            alarm.append(i == 1000 ? 1 : 0);
        }
        const auto out = Downsampler::minMax(in, 800, alarm);
        bool found = false;
        for (const auto &p : out) {
            if (qFuzzyCompare(p.x, 1000000.0))
                found = true;
        }
        QVERIFY2(found, "alarm point must be anchored in output");
    }

    void envelopeKept()
    {
        // Min/max toàn cục phải có mặt (envelope đúng).
        const auto in = sineWithSpike(4000, 100, -50.0);
        const auto out = Downsampler::minMax(in, 800);
        double lo = out.first().y, hi = out.first().y;
        for (const auto &p : out) {
            lo = qMin(lo, p.y);
            hi = qMax(hi, p.y);
        }
        QCOMPARE(lo, -50.0);
        QVERIFY(hi > 14.0); // đỉnh sine ~15 phải còn
    }
};

QTEST_MAIN(TestDownsampler)
#include "downsampler_test.moc"
