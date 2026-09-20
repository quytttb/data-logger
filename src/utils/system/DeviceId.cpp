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
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[DeviceId] Cannot open /proc/cpuinfo";
        return {};
    }

    QByteArray content = f.readAll();
    qDebug() << "[DeviceId] Read" << content.size() << "bytes from /proc/cpuinfo";
    
    QList<QByteArray> lines = content.split('\n');
    qDebug() << "[DeviceId] Parsing" << lines.size() << "lines";
    
    for (const QByteArray &line : lines) {
        if (!line.contains("Serial"))
            continue;
            
        qDebug() << "[DeviceId] Found 'Serial' line:" << line;
        
        const int colon = line.indexOf(':');
        if (colon < 0) {
            qDebug() << "[DeviceId] No colon found in line";
            continue;
        }
        
        QString serial = QString::fromLatin1(line.mid(colon + 1)).trimmed();
        qDebug() << "[DeviceId] Serial before cleanup:" << serial;
        
        serial.remove(QRegularExpression(QStringLiteral("[^0-9a-fA-F]")));
        qDebug() << "[DeviceId] Serial after cleanup:" << serial;
        
        if (!serial.isEmpty())
            return serial;
    }
    
    qWarning() << "[DeviceId] Serial field not found";
    return {};
}

QString effectiveHardwareId()
{
    const QString serial = readCpuSerial();
    if (!serial.isEmpty())
        return serial;
    
    // Fallback only for desktop development (non-Pi).
    // On Pi without readable /proc/cpuinfo Serial, treat as hardware fault
    // rather than silently using SD-card-resident machine-id (defeats lock).
    // Check if we're on a Pi by testing for /proc/device-tree (Pi-specific).
    QFile piMarker(QStringLiteral("/proc/device-tree/model"));
    if (piMarker.exists()) {
        // We're on a Pi but CPU serial is unreadable → return empty to fail lock
        qWarning() << "[DeviceId] Running on Pi but CPU serial not readable from /proc/cpuinfo";
        return {};
    }
    
    // Dev/non-Pi fallback so desktop builds remain runnable.
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
