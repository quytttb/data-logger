#include "network/modbus/ModbusWorker.h"

#include <QtTest>

// Audit M5/P2-14: hysteresis alarm band — pure static, no Modbus hardware
// needed. Verifies that the release band differs from the trigger band so
// relays do not chatter around min_threshold / max_threshold.
class TestAlarmHysteresis : public QObject
{
    Q_OBJECT

private slots:
    void noHysteresis_triggersAtThreshold();
    void noHysteresis_releasesAtThreshold();
    void hysteresis_holdsAlarmInsideBand();
    void hysteresis_releasesOutsideBand();
    void hysteresis_minSide();
};

void TestAlarmHysteresis::noHysteresis_triggersAtThreshold()
{
    QString type;
    // max_th = 50, value 51, hysteresis 0, not previously in alarm.
    const bool a = ModbusWorker::evaluateAlarmWithHysteresis(
        51.0, /*wasAlarm*/ false, QString(),
        /*hasMin*/ false, 0.0, /*hasMax*/ true, 50.0, 0.0, type);
    QVERIFY(a);
    QCOMPARE(type, QStringLiteral("max"));
}

void TestAlarmHysteresis::noHysteresis_releasesAtThreshold()
{
    QString type;
    const bool a = ModbusWorker::evaluateAlarmWithHysteresis(
        49.0, /*wasAlarm*/ true, QStringLiteral("max"),
        false, 0.0, true, 50.0, 0.0, type);
    QVERIFY(!a);
    QVERIFY(type.isEmpty());
}

void TestAlarmHysteresis::hysteresis_holdsAlarmInsideBand()
{
    QString type;
    // max_th = 50, hyst = 1. Value 50.5 is INSIDE the release band
    // (still >= 49), so the alarm must LINGER even though the value is now
    // below the raw threshold.
    const bool a = ModbusWorker::evaluateAlarmWithHysteresis(
        50.5, /*wasAlarm*/ true, QStringLiteral("max"),
        false, 0.0, true, 50.0, 1.0, type);
    QVERIFY(a);
    QCOMPARE(type, QStringLiteral("max"));
}

void TestAlarmHysteresis::hysteresis_releasesOutsideBand()
{
    QString type;
    // Value 48.9 is below (maxTh - hyst) = 49 → outside band → release.
    const bool a = ModbusWorker::evaluateAlarmWithHysteresis(
        48.9, /*wasAlarm*/ true, QStringLiteral("max"),
        false, 0.0, true, 50.0, 1.0, type);
    QVERIFY(!a);
    QVERIFY(type.isEmpty());
}

void TestAlarmHysteresis::hysteresis_minSide()
{
    QString type;
    // min_th = 10, hyst = 1. In alarm (min); value 10.5 is inside the release
    // band (still <= 11) → hold. Value 11.2 > 11 → release.
    const bool hold = ModbusWorker::evaluateAlarmWithHysteresis(
        10.5, /*wasAlarm*/ true, QStringLiteral("min"),
        true, 10.0, false, 0.0, 1.0, type);
    QVERIFY(hold);
    QCOMPARE(type, QStringLiteral("min"));

    const bool release = ModbusWorker::evaluateAlarmWithHysteresis(
        11.2, /*wasAlarm*/ true, QStringLiteral("min"),
        true, 10.0, false, 0.0, 1.0, type);
    QVERIFY(!release);
}

QTEST_APPLESS_MAIN(TestAlarmHysteresis)
#include "alarm_hysteresis_test.moc"
