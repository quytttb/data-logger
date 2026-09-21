#include "core/MonitorController.h"

#include <QtTest>
#include <QCoreApplication>

class TestMonitorRetry : public QObject
{
    Q_OBJECT

private slots:
    void testBackoffDelays()
    {
        // Base is 5000ms (5s)
        // Retry 0: 5s
        QCOMPARE(MonitorController::computeRetryDelayMs(0), 5000);
        // Retry 1: 10s
        QCOMPARE(MonitorController::computeRetryDelayMs(1), 10000);
        // Retry 2: 20s
        QCOMPARE(MonitorController::computeRetryDelayMs(2), 20000);
        // Retry 3: 40s
        QCOMPARE(MonitorController::computeRetryDelayMs(3), 40000);
        // Retry 4: 60s (capped from 80s)
        QCOMPARE(MonitorController::computeRetryDelayMs(4), 60000);
        // Retry 5+: still capped at 60s
        QCOMPARE(MonitorController::computeRetryDelayMs(5), 60000);
        QCOMPARE(MonitorController::computeRetryDelayMs(10), 60000);
        // Negative count fallback to 0
        QCOMPARE(MonitorController::computeRetryDelayMs(-1), 5000);
    }
};

QTEST_MAIN(TestMonitorRetry)
#include "monitor_retry_test.moc"
