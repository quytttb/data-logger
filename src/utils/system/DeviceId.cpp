#include "DeviceId.h"
#include <QSysInfo>

namespace DeviceId {

QString stationCode()
{
    // QSysInfo::machineUniqueId() reads /etc/machine-id on Linux (Raspberry Pi).
    // It returns a raw hex byte-array like "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4".
    QByteArray mid = QSysInfo::machineUniqueId();
    if (mid.isEmpty())
        return QStringLiteral("DL-00000000");

    // Use the first 8 hex characters so the code stays compact and URL-safe.
    QString hex = QString::fromLatin1(mid).left(8).toUpper();
    return QStringLiteral("DL-") + hex;
}

} // namespace DeviceId
