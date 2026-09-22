#include <QtTest>
#include "core/tt10/SensorSymbols.h"

// Tên đầy đủ hiển thị: Symbol_Tên (Monitor cards/list + bảng Sensors).
class SensorSymbolsTest : public QObject {
    Q_OBJECT

private slots:
    void displayLabelUnderscore();
    void displayLabelEmptyCases();
};

void SensorSymbolsTest::displayLabelUnderscore()
{
    QCOMPARE(SensorSymbols::displayLabel(QStringLiteral("Temp"),
                                         QStringLiteral("Temperature")),
             QString("Temp_Temperature"));
    QCOMPARE(SensorSymbols::displayLabel(QStringLiteral("RH"),
                                         QStringLiteral("Humidity")),
             QString("RH_Humidity"));
}

void SensorSymbolsTest::displayLabelEmptyCases()
{
    // Chưa gán symbol (vd DI/DO) → giữ nguyên tên.
    QCOMPARE(SensorSymbols::displayLabel(QString(),
                                         QStringLiteral("Monitoring status")),
             QString("Monitoring status"));
    // Tên trống → chỉ symbol.
    QCOMPARE(SensorSymbols::displayLabel(QStringLiteral("Temp"), QString()),
             QString("Temp"));
    QCOMPARE(SensorSymbols::displayLabel(QString(), QString()), QString());
}

QTEST_MAIN(SensorSymbolsTest)
#include "sensor_symbols_test.moc"
