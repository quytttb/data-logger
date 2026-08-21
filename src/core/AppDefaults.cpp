#include "AppDefaults.h"
#include "utils/system/AppDefaults.h"
#include "utils/modbus/ModbusCodec.h"

IMPLEMENT_QML_SINGLETON(AppDefaultsQml)

AppDefaultsQml::AppDefaultsQml(QObject *parent) : QObject(parent) {}

int AppDefaultsQml::modbusTcpPort() const { return AppDefaults::modbusTcpPort; }
int AppDefaultsQml::restApiPort() const   { return AppDefaults::restApiPort; }
QString AppDefaultsQml::bindAny() const    { return AppDefaults::bindAnyIPv4; }
QString AppDefaultsQml::timezone() const   { return AppDefaults::timezone; }
QString AppDefaultsQml::timeFormat() const { return AppDefaults::timeFormat; }
QString AppDefaultsQml::dateFormat() const { return AppDefaults::dateFormat; }

QStringList AppDefaultsQml::baudrates() const
{
    QStringList out;
    for (int b : ModbusCodec::supportedBaudrates())
        out << QString::number(b);
    return out;
}

QStringList AppDefaultsQml::dataTypes() const
{
    return ModbusCodec::supportedDataTypes();
}

QStringList AppDefaultsQml::byteOrders() const
{
    return ModbusCodec::supportedDataFormats();
}

QStringList AppDefaultsQml::parityOptions() const
{
    return {QStringLiteral("N"), QStringLiteral("E"), QStringLiteral("O")};
}