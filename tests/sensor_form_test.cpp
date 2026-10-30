#include "core/SensorListModel.h"
#include "utils/calc/CalibrationMath.h"

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
        };
        QCOMPARE(SensorListModel::validateSensorProps(form), QString());
    }

    void invalidFieldsRejected()
    {
        QVariantMap blankName{
            {QStringLiteral("name"), QStringLiteral("  ")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 0},
        };
        QVERIFY(!SensorListModel::validateSensorProps(blankName).isEmpty());
        QVariantMap badSlave{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 248},
            {QStringLiteral("registerAddress"), 0},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badSlave).isEmpty());

        QVariantMap badAddr{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 70000},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badAddr).isEmpty());

        QVariantMap badDecimals{
            {QStringLiteral("name"), QStringLiteral("T")},
            {QStringLiteral("slaveId"), 1},
            {QStringLiteral("registerAddress"), 0},
            {QStringLiteral("decimals"), 7},
        };
        QVERIFY(!SensorListModel::validateSensorProps(badDecimals).isEmpty());
    }

    void coefficientModes()
    {
        QString error;
        QCOMPARE(SensorListModel::buildCoefficientJson(0, {}, {}, {}, &error),
                 QStringLiteral("{}"));

        const QString linear = SensorListModel::buildCoefficientJson(
            1, {}, QStringLiteral("2"), QStringLiteral("0.5"), &error);
        QVERIFY(error.isEmpty());
        QCOMPARE(linear, QStringLiteral("{\"a\":2,\"b\":0.5}"));

        const QString bad = SensorListModel::buildCoefficientJson(
            1, {}, QStringLiteral("abc"), {}, &error);
        QVERIFY(bad.isEmpty());
        QVERIFY(!error.isEmpty());

        const QString advanced = SensorListModel::buildCoefficientJson(
            2, QStringLiteral("{\"k\":1}"), {}, {}, &error);
        QCOMPARE(advanced, QStringLiteral("{\"k\":1}"));

        const QString badJson = SensorListModel::buildCoefficientJson(
            2, QStringLiteral("{nope"), {}, {}, &error);
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

        // JSON legacy/không hiểu rõ giữ nguyên ở Advanced, không mất dữ liệu.
        const QVariantMap legacy = SensorListModel::coefficientUiState(
            QStringLiteral("{\"coeffs\":[1,2]}"));
        QCOMPARE(legacy.value(QStringLiteral("mode")).toInt(), 2);
        QCOMPARE(legacy.value(QStringLiteral("legacyJson")).toString(),
                 QStringLiteral("{\"coeffs\":[1,2]}"));

        const QVariantMap broken = SensorListModel::coefficientUiState(QStringLiteral("{nope"));
        QCOMPARE(broken.value(QStringLiteral("mode")).toInt(), 2);
        QCOMPARE(broken.value(QStringLiteral("legacyJson")).toString(),
                 QStringLiteral("{nope"));

        const QString extended = QStringLiteral("{\"a\":2,\"b\":3,\"metadata\":\"keep\"}");
        const QVariantMap extra = SensorListModel::coefficientUiState(extended);
        QCOMPARE(extra.value(QStringLiteral("mode")).toInt(), 2);
        QCOMPARE(extra.value(QStringLiteral("legacyJson")).toString(), extended);
        QCOMPARE(SensorListModel::coefficientUiState(QStringLiteral("{\"a\":2}"))
                     .value(QStringLiteral("mode")).toInt(), 2);

        const QString precise = QStringLiteral("{\"a\":0.12345678901234566,\"b\":-9876.543210987654}");
        const QVariantMap uiPrecise = SensorListModel::coefficientUiState(precise);
        QString error;
        const QString saved = SensorListModel::buildCoefficientJson(
            uiPrecise.value(QStringLiteral("mode")).toInt(), {},
            uiPrecise.value(QStringLiteral("linearA")).toString(),
            uiPrecise.value(QStringLiteral("linearB")).toString(), &error);
        double beforeA, beforeB, afterA, afterB;
        QVERIFY(CalibrationMath::parseCoefficient(precise, &beforeA, &beforeB));
        QVERIFY(CalibrationMath::parseCoefficient(saved, &afterA, &afterB));
        QCOMPARE(beforeA, afterA);
        QCOMPARE(beforeB, afterB);
    }

    void nullStringsCoerced()
    {
        // Combo chưa chọn đưa null QString (QML undefined) — phải ép về ""
        // nếu không DAO bind NULL và vi phạm NOT NULL của sensor_symbol/unit.
        const QString nullStr;
        QVERIFY(nullStr.isNull());
        QCOMPARE(SensorListModel::nonNullString(QVariant()), QStringLiteral(""));
        QCOMPARE(SensorListModel::nonNullString(QVariant(nullStr)), QStringLiteral(""));
        QCOMPARE(SensorListModel::nonNullString(QVariant(QStringLiteral("CO"))),
                 QStringLiteral("CO"));
        QCOMPARE(SensorListModel::nonNullString(QVariant(), QStringLiteral("holding")),
                 QStringLiteral("holding"));
        // Giá trị rỗng thường (không null) giữ nguyên.
        QVERIFY(!SensorListModel::nonNullString(QVariant(QStringLiteral(""))).isNull());
    }
};

QTEST_MAIN(TestSensorForm)
#include "sensor_form_test.moc"
