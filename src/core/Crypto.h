#pragma once
#include <QString>
// Simple base64 obfuscation for stored passwords.
// Replace with AES/PBKDF2 for production hardening.
namespace Crypto {
QString encrypt(const QString &plain);
QString decrypt(const QString &cipher);
}
