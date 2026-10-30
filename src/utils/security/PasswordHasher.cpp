#include "PasswordHasher.h"

#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QStringList>
#include <QtDebug>

namespace PasswordHasher {

namespace {

constexpr char kAlgorithm[] = "pbkdf2-sha256";
constexpr char kSeparator = '$';
constexpr int kHashLen = 32;  // SHA-256
// Chặn chuỗi băm bị sửa trong DB làm treo thiết bị (DoS khi đăng nhập).
constexpr int kMaxIterations = 10'000'000;

QByteArray randomSalt(int bytes)
{
    QByteArray salt(bytes, Qt::Uninitialized);
    QRandomGenerator *gen = QRandomGenerator::system();
    for (int i = 0; i < bytes;) {
        const quint32 value = gen->generate();
        for (int j = 0; j < 4 && i < bytes; ++j, ++i)
            salt[i] = char((value >> (8 * j)) & 0xFF);
    }
    return salt;
}

QByteArray hmacSha256(const QByteArray &key, const QByteArray &data)
{
    QMessageAuthenticationCode mac(QCryptographicHash::Sha256, key);
    mac.addData(data);
    return mac.result();
}

bool constantTimeEquals(const QByteArray &a, const QByteArray &b)
{
    if (a.size() != b.size())
        return false;
    unsigned char diff = 0;
    for (int i = 0; i < a.size(); ++i)
        diff |= static_cast<unsigned char>(a.at(i)) ^ static_cast<unsigned char>(b.at(i));
    return diff == 0;
}

QByteArray normalizedPassword(const QString &password)
{
    // NFC để cùng một mật khẩu gõ trên bàn phím khác nhau vẫn băm giống nhau.
    return password.normalized(QString::NormalizationForm_C).toUtf8();
}

} // namespace

QByteArray deriveKey(const QByteArray &password, const QByteArray &salt,
                     int iterations, int keyBytes)
{
    if (password.isEmpty() || salt.isEmpty() || iterations < 1 || keyBytes < 1)
        return {};

    const int blockCount = (keyBytes + kHashLen - 1) / kHashLen;
    QByteArray derived;
    derived.reserve(blockCount * kHashLen);

    for (int block = 1; block <= blockCount; ++block) {
        QByteArray index(4, '\0');
        index[0] = char((block >> 24) & 0xFF);
        index[1] = char((block >> 16) & 0xFF);
        index[2] = char((block >> 8) & 0xFF);
        index[3] = char(block & 0xFF);

        QByteArray u = hmacSha256(password, salt + index);
        QByteArray t = u;
        for (int i = 1; i < iterations; ++i) {
            u = hmacSha256(password, u);
            for (int k = 0; k < kHashLen; ++k)
                t[k] = char(static_cast<unsigned char>(t.at(k))
                            ^ static_cast<unsigned char>(u.at(k)));
        }
        derived.append(t);
    }

    derived.truncate(keyBytes);
    return derived;
}

QString hash(const QString &password, const Params &params)
{
    if (password.isEmpty() || params.iterations < 1 || params.saltBytes < 8
        || params.keyBytes < 16 || params.iterations > kMaxIterations) {
        return {};
    }

    const QByteArray salt = randomSalt(params.saltBytes);
    QByteArray raw = normalizedPassword(password);
    const QByteArray key = deriveKey(raw, salt, params.iterations, params.keyBytes);
    raw.fill('\0');  // hạn chế plaintext nằm lâu trong bộ nhớ

    if (key.isEmpty())
        return {};

    return QStringLiteral("%1$%2$%3$%4")
        .arg(QString::fromLatin1(kAlgorithm),
             QString::number(params.iterations),
             QString::fromLatin1(salt.toBase64()),
             QString::fromLatin1(key.toBase64()));
}

bool verify(const QString &password, const QString &encoded, bool *needsRehash)
{
    if (needsRehash)
        *needsRehash = false;
    if (password.isEmpty() || encoded.isEmpty())
        return false;

    const QStringList parts = encoded.split(QLatin1Char(kSeparator));
    if (parts.size() != 4 || parts.at(0) != QLatin1String(kAlgorithm))
        return false;

    bool ok = false;
    const int iterations = parts.at(1).toInt(&ok);
    if (!ok || iterations < 1 || iterations > kMaxIterations)
        return false;

    const QByteArray salt = QByteArray::fromBase64(parts.at(2).toLatin1());
    const QByteArray expected = QByteArray::fromBase64(parts.at(3).toLatin1());
    if (salt.isEmpty() || expected.isEmpty() || expected.size() < 16)
        return false;

    QByteArray raw = normalizedPassword(password);
    const QByteArray actual = deriveKey(raw, salt, iterations, expected.size());
    raw.fill('\0');

    if (!constantTimeEquals(actual, expected))
        return false;

    if (needsRehash) {
        const Params current;
        *needsRehash = iterations < current.iterations
                    || salt.size() < current.saltBytes
                    || expected.size() < current.keyBytes;
    }
    return true;
}

} // namespace PasswordHasher
