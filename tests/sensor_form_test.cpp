#include "core/SensorListModel.h"

#include <QtTest>
#include <QCoreApplication>

// Sensor form logic is centralized in SensorListModel (static, no DB):
// field validation + coefficient codec. Locks the behavior so QML form
// changes cannot silently drift from what C++ accepts.
class TestSensorForm : public QObject
{
    Q_OBJECT

private slots:
    void validFormPasses()
    {
        QVariantMap form{
            {QStringLiteral("name"), QStringLiteral("Temp")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 0},
            {QStringLiteral("pollInterval"), 3},
        };
        QCOMPARE(SensorListModel::validateSensorProps(form), QString());
    }

    void invalidFieldsRejected()
    {
        QVariantMap blankName{
            {QStringLiteral("name"), QStringLiteral("  ")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 0},
            {QStringLiteral("pollInterval"), 3},
        };
        QVERIFY(!SensorListModel::validateSensorProps(blankName).isEmpty());

        QVariantMap badSlave{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 248},
            {QStringLiteral("registerAddress"), 0},
            {QStringLiteral("pollInterval"), 3},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badSlave).isEmpty());

        QVariantMap badAddr{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 70000},
            {QStringLiteral("pollInterval"), 3},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badAddr).isEmpty());

        QVariantMap badPoll{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 0},
            {QStringLiteral("pollInterval"), 0},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badPoll).isEmpty());
    }

    void coefficientModes()
    {
        QString error;
        QCOMPARE(SensorListModel::buildCoefficientJson(0, {}, {}, {}, {}, {}, &error),
                 QStringLiteral("{}"));

        const QString linear = SensorListModel::buildCoefficientJson(
            1, {}, QStringLiteral("2"), QStringLiteral("0.5"), {}, {}, &error);
        QVERIFY(error.isEmpty());
        QCOMPARE(linear, QStringLiteral("{\"a\":2,\"b\":0.5}"));

        const QString bad = SensorListModel::buildCoefficientJson(
            1, {}, QStringLiteral("abc"), {}, {}, {}, &error);
        QVERIFY(bad.isEmpty());
        QVERIFY(!error.isEmpty());

        error.clear();
        const QString scaled = SensorListModel::buildCoefficientJson(
            2, {}, QStringLiteral("4000"), QStringLiteral("20000"),
            QStringLiteral("4"), QStringLiteral("20"), &error);
        QVERIFY(error.isEmpty());
        QVERIFY(scaled.startsWith(QStringLiteral("{\"a\":")));

        const QString legacy = SensorListModel::buildCoefficientJson(
            3, QStringLiteral("{\"k\":1}"), {}, {}, {}, {}, &error);
        QCOMPARE(legacy, QStringLiteral("{\"k\":1}"));

        const QString badJson = SensorListModel::buildCoefficientJson(
            3, QStringLiteral("{nope"), {}, {}, {}, {}, &error);
        QVERIFY(badJson.isEmpty());
        QVERIFY(!error.isEmpty());
    }

    void coefficientUiStateRoundTrip()
    {
        const QVariantMap ui = SensorListModel::coefficientUiState(
            QStringLiteral("{\"a\":2,\"b\":0.5}"));
        QCOMPARE(ui.value(QStringLiteral("mode")).toInt(), 1);
        QCOMPARE(ui.value(QStringLiteral("linearA")).toString(), QStringLiteral("2"));

        const QVariantMap blank = SensorListModel::coefficientUiState(QStringLiteral("{}"));
        QCOMPARE(blank.value(QStringLiteral("mode")).toInt(), 0);
    }
};

QTEST_MAIN(TestSensorForm)
#include "sensor_form_test.moc"
