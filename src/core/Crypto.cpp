#include "Crypto.h"
#include <QByteArray>
namespace Crypto {
QString encrypt(const QString &plain) {
    return QString::fromLatin1(plain.toUtf8().toBase64());
}
QString decrypt(const QString &cipher) {
    return QString::fromUtf8(QByteArray::fromBase64(cipher.toLatin1()));
}
}
