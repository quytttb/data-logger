#include "utils/system/AppDefaults.h"
#include "utils/modbus/ModbusCodec.h"
#include "data/models/AppConfig.h"

#include <QtTest>
#include <QCoreApplication>

// Phủ tính nhất quán giữa AppDefaults (nguồn dùng chung) và AppConfig (runtime)
// cùng ModbusCodec (decoder + danh sách option). Tránh drift khi thêm/sửa default.
class TestAppDefaults : public QObject
{
    Q_OBJECT

private slots:
    void structDefaultsMatchAppDefaults()
    {
        AppConfig c;

        QCOMPARE(c.stationName, AppDefaults::stationName);
        QCOMPARE(c.timeFormat, AppDefaults::timeFormat);
        QCOMPARE(c.dateFormat, AppDefaults::dateFormat);
        QCOMPARE(c.timezone, AppDefaults::timezone);

        QCOMPARE(c.ftpPort, AppDefaults::ftpPort);
        QCOMPARE(c.ftpRemotePath, AppDefaults::ftpRemotePath);
        QCOMPARE(c.ftpProtocol, AppDefaults::ftpProtocol);

        QCOMPARE(c.pollInterval, AppDefaults::pollInterval);

        QCOMPARE(c.serialPort, AppDefaults::serialPort);
        QCOMPARE(c.serialBaudrate, AppDefaults::serialBaudrate);
        QCOMPARE(c.serialBytesize, AppDefaults::serialBytesize);
        QCOMPARE(c.serialParity, AppDefaults::serialParity);
        QCOMPARE(c.serialStopbits, AppDefaults::serialStopbits);

        QCOMPARE(c.modbusTcpPort, AppDefaults::modbusTcpPort);
        QCOMPARE(c.modbusTcpBind, AppDefaults::bindAnyIPv4);
        QCOMPARE(c.modbusTcpUnitId, AppDefaults::modbusTcpUnitId);

        QCOMPARE(c.restApiPort, AppDefaults::restApiPort);
        QCOMPARE(c.restApiBind, AppDefaults::bindAnyIPv4);

        QCOMPARE(c.serverDeviceType, AppDefaults::serverDeviceType);
        QCOMPARE(c.serverSendInterval, AppDefaults::serverSendInterval);
        QCOMPARE(c.serverStartTime, AppDefaults::serverStartTime);
        QCOMPARE(c.serverTimeFolder, AppDefaults::serverTimeFolder);
        QCOMPARE(c.fileSuffix, AppDefaults::fileSuffix);

        QCOMPARE(c.configRevision, AppDefaults::configRevision);
        QCOMPARE(c.uiLocale, AppDefaults::uiLocale);
        QCOMPARE(c.theme, AppDefaults::theme);
    }

    void modbusOptionLists()
    {
        const auto baudrates = ModbusCodec::supportedBaudrates();
        QCOMPARE(baudrates.size(), 8);
        QVERIFY(baudrates.contains(1200));
        QVERIFY(baudrates.contains(9600));
        QVERIFY(baudrates.contains(115200));
        QVERIFY(!ModbusCodec::isSupportedBaudrate(1234));
        QVERIFY(ModbusCodec::isSupportedBaudrate(AppDefaults::serialBaudrate));

        const auto types = ModbusCodec::supportedDataTypes();
        QCOMPARE(types.size(), 5);
        QVERIFY(types.contains(QStringLiteral("int16")));
        QVERIFY(types.contains(QStringLiteral("float32")));

        const auto formats = ModbusCodec::supportedDataFormats();
        QCOMPARE(formats.size(), 6);
        QVERIFY(formats.contains(QStringLiteral("AB")));
        QVERIFY(formats.contains(QStringLiteral("DCBA")));
    }
};

QTEST_MAIN(TestAppDefaults)
#include "app_defaults_test.moc"