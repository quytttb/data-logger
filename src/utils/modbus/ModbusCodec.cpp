#include "ModbusCodec.h"
#include <cstring>

namespace ModbusCodec {

QString normalizeRegisterType(const QString &uiLabel) {
    const QString s = uiLabel.trimmed().toLower();
    if (s.contains(QLatin1String("input register"))) return QStringLiteral("input");
    if (s.contains(QLatin1String("holding")))        return QStringLiteral("holding");
    if (s.contains(QLatin1String("coil")))           return QStringLiteral("coil");
    if (s.contains(QLatin1String("discrete")))       return QStringLiteral("discrete_input");
    return s;
}

int registerCountForDataType(const QString &dataType) {
    const QString dt = dataType.toLower();
    if (dt == QLatin1String("float32")
        || dt == QLatin1String("int32")
        || dt == QLatin1String("uint32"))
        return 2;
    return 1;
}

double decodeRegisters(const QVector<quint16> &regs,
                       const QString &dataType,
                       const QString &dataFormat) {
    if (regs.isEmpty()) return 0.0;

    const QString dt = dataType.toLower();
    if (dt == QLatin1String("uint16")) return regs[0];
    if (dt == QLatin1String("int16"))  return static_cast<qint16>(regs[0]);

    if (regs.size() < 2) return regs[0];

    const QString f = dataFormat.toUpper();
    const quint32 raw32 = (f == QLatin1String("CDAB") || f == QLatin1String("BA"))
        ? ((quint32(regs[1]) << 16) | regs[0])
        : ((quint32(regs[0]) << 16) | regs[1]);

    if (dt == QLatin1String("uint32")) return static_cast<double>(raw32);
    if (dt == QLatin1String("int32"))  return static_cast<double>(static_cast<qint32>(raw32));
    if (dt == QLatin1String("float32")) {
        float fv = 0.0f;
        std::memcpy(&fv, &raw32, sizeof(float));
        return fv;
    }
    return regs[0];
}

QModbusDataUnit::RegisterType toRegisterEnum(const QString &normalized) {
    if (normalized == QLatin1String("input"))          return QModbusDataUnit::InputRegisters;
    if (normalized == QLatin1String("coil"))           return QModbusDataUnit::Coils;
    if (normalized == QLatin1String("discrete_input")) return QModbusDataUnit::DiscreteInputs;
    return QModbusDataUnit::HoldingRegisters;
}

} // namespace ModbusCodec
