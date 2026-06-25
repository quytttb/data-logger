#include "LanIp.h"
#include <QNetworkInterface>

namespace LanIp {

QString primaryLanIp() {
    for (const QNetworkInterface &iface : QNetworkInterface::allInterfaces()) {
        auto flags = iface.flags();
        if (!(flags & QNetworkInterface::IsUp)) continue;
        if (!(flags & QNetworkInterface::IsRunning)) continue;
        if (flags & QNetworkInterface::IsLoopBack) continue;

        for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
            QHostAddress addr = entry.ip();
            if (addr.protocol() == QAbstractSocket::IPv4Protocol) {
                QString ip = addr.toString();
                if (!ip.startsWith("127.")) return ip;
            }
        }
    }
    return "127.0.0.1";
}

} // namespace LanIp
