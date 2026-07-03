#include "DeviceId.h"
#include <QFile>
#include <QSysInfo>
#include <QCryptographicHash>
#include <QRegularExpression>

namespace DeviceId {

namespace {

QString readCpuSerial()
{
    QFile f(QStringLiteral("/proc/cpuinfo"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    while (!f.atEnd()) {
        const QByteArray line = f.readLine().trimmed();
        if (!line.startsWith("Serial"))
            continue;
        const int colon = line.indexOf(':');
        if (colon < 0)
            continue;
        QString serial = QString::fromLatin1(line.mid(colon + 1)).trimmed();
        serial.remove(QRegularExpression(QStringLiteral("[^0-9a-fA-F]")));
        return serial;
    }
    return {};
}

QString effectiveHardwareId()
{
    const QString serial = readCpuSerial();
    if (!serial.isEmpty())
        return serial;
    // Dev / non-Pi fallback so desktop builds remain runnable.
    const QByteArray mid = QSysInfo::machineUniqueId();
    if (mid.isEmpty())
        return {};
    return QString::fromLatin1(mid.toHex());
}

} // namespace

QString hardwareSerial()
{
    return readCpuSerial();
}

QString stationCode()
{
    const QString id = effectiveHardwareId();
    if (id.isEmpty())
        return QStringLiteral("DL-00000000");

    const QString hex = id.right(8).toUpper();
    return QStringLiteral("DL-") + hex;
}

QString fingerprint()
{
    const QByteArray id = effectiveHardwareId().toUtf8();
    if (id.isEmpty())
        return {};
    return QString::fromLatin1(
        QCryptographicHash::hash(id, QCryptographicHash::Sha256).toHex());
}

} // namespace DeviceId
