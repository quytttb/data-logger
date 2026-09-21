#include <QtTest>
#include "core/MonitorModel.h"
#include "core/MonitorTableModel.h"

static QVariantMap sensorMap(int id, const QString &name, const QString &type)
{
    return QVariantMap{
        {QStringLiteral("id"), id},
        {QStringLiteral("name"), name},
        {QStringLiteral("unit"), QStringLiteral("°C")},
        {QStringLiteral("decimals"), 2},
        {QStringLiteral("sensor_type"), type},
    };
}

class MonitorTableModelTest : public QObject {
    Q_OBJECT

private slots:
    void headersAndMirror();
    void digitalFilter();
    void liveUpdate();
};

void MonitorTableModelTest::headersAndMirror()
{
    MonitorModel source(nullptr);
    source.loadSensors({sensorMap(1, QStringLiteral("T1"), QStringLiteral("ANALOG")),
                        sensorMap(2, QStringLiteral("DI1"), QStringLiteral("DI"))});

    MonitorTableModel m;
    QCOMPARE(m.columnCount(), 4);
    QCOMPARE(m.headerData(0, Qt::Horizontal), QVariant("Sensor"));
    QCOMPARE(m.headerData(1, Qt::Horizontal), QVariant("Value"));
    QCOMPARE(m.headerData(2, Qt::Horizontal), QVariant("Unit"));
    QCOMPARE(m.headerData(3, Qt::Horizontal), QVariant("Status"));

    m.setSourceModel(&source);
    QCOMPARE(m.rowCount(), 2);
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::DisplayNameRole).toString(),
             QString("T1"));
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::SensorTypeRole).toString(),
             QString("ANALOG"));
    QCOMPARE(m.data(m.index(1, 0), MonitorTableModel::SensorTypeRole).toString(),
             QString("DI"));
    // Chưa poll: value mặc định "---".
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::ValueRole).toString(),
             QString("---"));
}

void MonitorTableModelTest::digitalFilter()
{
    MonitorModel source(nullptr);
    source.loadSensors({sensorMap(1, QStringLiteral("T1"), QStringLiteral("ANALOG")),
                        sensorMap(2, QStringLiteral("DI1"), QStringLiteral("DI")),
                        sensorMap(3, QStringLiteral("DO1"), QStringLiteral("DO"))});

    MonitorTableModel m;
    m.setShowDigitalIO(false);
    m.setSourceModel(&source);
    QCOMPARE(m.rowCount(), 1);
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::DisplayNameRole).toString(),
             QString("T1"));

    m.setShowDigitalIO(true);
    QCOMPARE(m.rowCount(), 3);
}

void MonitorTableModelTest::liveUpdate()
{
    MonitorModel source(nullptr);
    source.loadSensors({sensorMap(1, QStringLiteral("T1"), QStringLiteral("ANALOG"))});

    MonitorTableModel m;
    QSignalSpy countSpy(&m, &MonitorTableModel::countChanged);
    m.setSourceModel(&source);
    QCOMPARE(countSpy.count(), 1);

    // Poll update từ source phải phản chiếu sang table (rebuild đồng bộ).
    source.updateValue(1, 25.5, 2550, QStringLiteral("2026-09-21T10:00:00"),
                       false, {}, {});
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::ValueRole).toString(),
             QString("25.50"));

    // Alarm lan sang table.
    source.updateValue(1, 99.9, 9990, QStringLiteral("2026-09-21T10:01:00"),
                       true, QStringLiteral("max"), {});
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::IsAlarmRole).toBool(), true);
    QCOMPARE(m.data(m.index(0, 0), MonitorTableModel::AlarmTypeRole).toString(),
             QString("max"));

    // loadSensors lại (reset source) → table rebuild đúng số dòng.
    source.loadSensors({sensorMap(1, QStringLiteral("T1"), QStringLiteral("ANALOG")),
                        sensorMap(4, QStringLiteral("T2"), QStringLiteral("ANALOG"))});
    QCOMPARE(m.rowCount(), 2);
    QVERIFY(countSpy.count() >= 3);
}

QTEST_MAIN(MonitorTableModelTest)
#include "monitor_table_model_test.moc"
