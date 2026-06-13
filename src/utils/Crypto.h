#pragma once
#include <QString>

namespace Crypto {
QString encrypt(const QString &plain);
QString decrypt(const QString &cipher);
}
