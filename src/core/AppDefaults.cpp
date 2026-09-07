#include "AppDefaults.h"
#include "utils/system/AppDefaults.h"
#include "utils/system/TimezoneOptions.h"
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

QVariantList AppDefaultsQml::timezoneOptions() const
{
    return TimezoneOptions::modelWithSystem(AppDefaults::timezone);
}

int AppDefaultsQml::timezoneIndex(const QString &tz) const
{
    const QVariantList model = timezoneOptions();
    const QString norm = TimezoneOptions::normalizeAlias(tz);
    for (int i = 0; i < model.size(); ++i) {
        if (model[i].toMap().value(QStringLiteral("value")).toString() == norm)
            return i;
    }
    // Unknown zone: fall back to the host system entry, never to row 0.
    const QString systemTz = AppDefaults::timezone;
    for (int i = 0; i < model.size(); ++i) {
        if (model[i].toMap().value(QStringLiteral("value")).toString() == systemTz)
            return i;
    }
    return 0;
}