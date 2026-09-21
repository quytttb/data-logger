#include "ModbusCodec.h"
#include <cstring>

namespace ModbusCodec {

QList<int> supportedBaudrates()
{
    return {1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200};
}

QStringList supportedDataTypes()
{
    return {QStringLiteral("int16"), QStringLiteral("uint16"),
            QStringLiteral("int32"), QStringLiteral("uint32"),
            QStringLiteral("float32")};
}

QStringList supportedDataFormats()
{
    return {QStringLiteral("AB"), QStringLiteral("BA"), QStringLiteral("ABCD"),
            QStringLiteral("CDAB"), QStringLiteral("BADC"), QStringLiteral("DCBA")};
}

bool isSupportedBaudrate(int baudrate)
{
    return supportedBaudrates().contains(baudrate);
}

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
    const QString f = dataFormat.toUpper().trimmed();

    // 16-bit: AB = big-endian (native), BA = byte swap
    if (dt == QLatin1String("uint16")) {
        if (f == QLatin1String("BA"))
            return ((regs[0] >> 8) & 0xFF) | ((regs[0] & 0xFF) << 8);
        return regs[0];
    }
    if (dt == QLatin1String("int16")) {
        const qint16 v = static_cast<qint16>(regs[0]);
        if (f == QLatin1String("BA")) {
            const quint16 swapped = ((regs[0] >> 8) & 0xFF) | ((regs[0] & 0xFF) << 8);
            return static_cast<qint16>(swapped);
        }
        return v;
    }

    if (regs.size() < 2) return regs[0];

    // 32-bit: byte order table
    //   regs[0] = word hi (theo thứ tự line), regs[1] = word lo
    //   ABCD: 12 34 56 78 -> 0x12345678
    //   CDAB: 56 78 12 34 -> word swap
    //   BADC: 34 12 78 56 -> byte swap trong từng word
    //   DCBA: 78 56 34 12 -> byte swap + word swap
    //   BA  : legacy alias của CDAB cho 32-bit (giữ tương thích test cũ)
    auto swapBytes16 = [](quint16 w) -> quint16 {
        return quint16(((w >> 8) & 0xFF) | ((w & 0xFF) << 8));
    };

    quint32 raw32 = 0;
    if (f == QLatin1String("CDAB") || f == QLatin1String("BA")) {
        raw32 = (quint32(regs[1]) << 16) | regs[0];
    } else if (f == QLatin1String("BADC")) {
        const quint16 hi = swapBytes16(regs[0]);
        const quint16 lo = swapBytes16(regs[1]);
        raw32 = (quint32(hi) << 16) | lo;
    } else if (f == QLatin1String("DCBA")) {
        const quint16 hi = swapBytes16(regs[1]);
        const quint16 lo = swapBytes16(regs[0]);
        raw32 = (quint32(hi) << 16) | lo;
    } else {
        // ABCD (default)
        raw32 = (quint32(regs[0]) << 16) | regs[1];
    }

    if (dt == QLatin1String("uint32")) return static_cast<double>(raw32);
    if (dt == QLatin1String("int32"))  return static_cast<double>(static_cast<qint32>(raw32));
    if (dt == QLatin1String("float32")) {
        float fv = 0.0f;
        std::memcpy(&fv, &raw32, sizeof(float));
        return fv;
    }
    return regs[0];
}

QVector<quint16> encodeRegisters(double value,
                                const QString &dataType,
                                const QString &dataFormat) {
    const QString dt = dataType.toLower();
    const QString f = dataFormat.toUpper().trimmed();
    auto swapBytes16 = [](quint16 w) -> quint16 {
        return quint16(((w >> 8) & 0xFF) | ((w & 0xFF) << 8));
    };

    // Guard NaN/Inf — caller nên validate trước, nhưng encode trả 0 để tránh UB
    if (!std::isfinite(value))
        return {};

    if (dt == QLatin1String("uint16") || dt == QLatin1String("int16")) {
        if (dt == QLatin1String("uint16")) {
            if (value < 0 || value > 65535.0)
                return {};
            quint16 w = quint16(static_cast<quint16>(value));
            if (f == QLatin1String("BA"))
                w = swapBytes16(w);
            return {w};
        } else {
            if (value < -32768.0 || value > 32767.0)
                return {};
            quint16 w = quint16(static_cast<qint16>(value));
            if (f == QLatin1String("BA"))
                w = swapBytes16(w);
            return {w};
        }
    }

    quint32 raw32 = 0;
    if (dt == QLatin1String("float32")) {
        float fv = float(value);
        if (!std::isfinite(fv))
            return {};
        std::memcpy(&raw32, &fv, sizeof(raw32));
    } else if (dt == QLatin1String("int32")) {
        if (value < double(INT32_MIN) || value > double(INT32_MAX))
            return {};
        raw32 = quint32(static_cast<qint32>(value));
    } else {
        if (value < 0 || value > double(UINT32_MAX))
            return {};
        raw32 = quint32(static_cast<quint32>(value));
    }
    const quint16 hi = quint16(raw32 >> 16);
    const quint16 lo = quint16(raw32 & 0xFFFF);

    if (f == QLatin1String("CDAB") || f == QLatin1String("BA")) {
        return {lo, hi};
    } else if (f == QLatin1String("BADC")) {
        return {swapBytes16(hi), swapBytes16(lo)};
    } else if (f == QLatin1String("DCBA")) {
        return {swapBytes16(lo), swapBytes16(hi)};
    }
    return {hi, lo}; // ABCD
}

QString validateSensorModbusConfig(const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat) {
    const QString rtRaw = registerType.trimmed();
    const QString rt = normalizeRegisterType(registerType);
    // Whitelist register_type — bao gồm cả "Invalid" ở UI
    if (rtRaw.compare(QStringLiteral("Invalid"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("Register type must be selected.");
    if (rt != QLatin1String("holding") && rt != QLatin1String("input")
        && rt != QLatin1String("coil") && rt != QLatin1String("discrete_input"))
        return QStringLiteral("Unsupported register type: %1").arg(registerType);

    const QString dt = dataType.toLower().trimmed();
    const QString df = dataFormat.toUpper().trimmed();

    const bool isCoil = (rt == QLatin1String("coil") || rt == QLatin1String("discrete_input"));
    if (isCoil) {
        // Coil/DI chỉ là bit — không dùng data_type/data_format
        return {};
    }

    const QStringList validTypes = supportedDataTypes();
    if (!validTypes.contains(dt, Qt::CaseInsensitive))
        return QStringLiteral("Unsupported data type: %1").arg(dataType);

    const QStringList validFormats = supportedDataFormats();
    if (!validFormats.contains(df, Qt::CaseInsensitive))
        return QStringLiteral("Unsupported byte order: %1").arg(dataFormat);

    // 16-bit chỉ hợp lệ với AB/BA
    const bool is16 = (dt == QLatin1String("int16") || dt == QLatin1String("uint16"));
    if (is16 && df != QLatin1String("AB") && df != QLatin1String("BA"))
        return QStringLiteral("16-bit type %1 only supports AB/BA, not %2").arg(dataType, dataFormat);

    // Coil/DI không cho data_type 32-bit (đã return sớm, đây là holding/input)
    return {};
}

QModbusDataUnit::RegisterType toRegisterEnum(const QString &normalized) {
    if (normalized == QLatin1String("input"))          return QModbusDataUnit::InputRegisters;
    if (normalized == QLatin1String("coil"))           return QModbusDataUnit::Coils;
    if (normalized == QLatin1String("discrete_input")) return QModbusDataUnit::DiscreteInputs;
    return QModbusDataUnit::HoldingRegisters;
}

} // namespace ModbusCodec
