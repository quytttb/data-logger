#include "Crypto.h"
#include "utils/system/AppPaths.h"

#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QtDebug>

#include <openssl/evp.h>
#include <openssl/rand.h>

namespace Crypto {

namespace {

constexpr const char *kEncPrefix = "enc1:";
constexpr int kKeyBytes  = 32;  // AES-256
constexpr int kIvBytes   = 12;  // GCM recommended nonce length
constexpr int kTagBytes  = 16;  // GCM authentication tag

// Khóa 256-bit lưu RIÊNG ngoài DB trong file 0600 — audit C1 yêu cầu key
// không nằm trong cùng file với dữ liệu cần bảo vệ.
QByteArray g_key;

QString keyFilePath()
{
    return QDir(AppPaths::configDir()).filePath(QStringLiteral("crypto.key"));
}

QByteArray loadOrGenerateKey()
{
    if (!g_key.isEmpty())
        return g_key;

    QFile file(keyFilePath());
    if (file.exists()) {
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "Crypto: cannot open key file" << file.fileName()
                       << "— secrets will not decrypt";
            return {};
        }
        const QByteArray raw = QByteArray::fromHex(file.readAll().trimmed());
        if (raw.size() == kKeyBytes) {
            g_key = raw;
            return g_key;
        }
        qWarning() << "Crypto: key file" << file.fileName()
                   << "is malformed — regenerating";
    }

    // First run (or corrupt key): generate a fresh random key.
    QByteArray key(kKeyBytes, Qt::Uninitialized);
    if (RAND_bytes(reinterpret_cast<unsigned char *>(key.data()), kKeyBytes) != 1) {
        qCritical() << "Crypto: RAND_bytes failed — cannot generate key";
        return {};
    }
    g_key = key;

    QDir().mkpath(AppPaths::configDir());
    QSaveFile saveFile(keyFilePath());
    if (!saveFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Crypto: cannot write key file" << saveFile.fileName();
        return g_key;
    }
    saveFile.write(g_key.toHex());
    saveFile.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (!saveFile.commit())
        qWarning() << "Crypto: failed to commit key file" << keyFilePath();
    return g_key;
}

QString legacyDecrypt(const QString &cipher)
{
    return QString::fromUtf8(QByteArray::fromBase64(cipher.toLatin1()));
}

QString legacyEncrypt(const QString &plain)
{
    return QString::fromLatin1(plain.toUtf8().toBase64());
}

QString aesEncrypt(const QString &plain)
{
    const QByteArray key = loadOrGenerateKey();
    if (key.size() != kKeyBytes)
        return legacyEncrypt(plain); // no key available — fall back (logged above)

    const QByteArray pt = plain.toUtf8();

    QVector<unsigned char> iv(kIvBytes);
    if (RAND_bytes(iv.data(), kIvBytes) != 1)
        return legacyEncrypt(plain);

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return legacyEncrypt(plain);

    QByteArray result;
    const QString fallback = legacyEncrypt(plain);
    bool ok = false;

    do {
        if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1)
            break;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, kIvBytes, nullptr) != 1)
            break;
        if (EVP_EncryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               iv.data()) != 1)
            break;

        QByteArray ct(pt.size() + EVP_MAX_BLOCK_LENGTH, Qt::Uninitialized);
        int outLen = 0;
        if (EVP_EncryptUpdate(ctx, reinterpret_cast<unsigned char *>(ct.data()), &outLen,
                              reinterpret_cast<const unsigned char *>(pt.constData()),
                              pt.size()) != 1)
            break;
        int total = outLen;
        if (EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(ct.data()) + total,
                                &outLen) != 1)
            break;
        total += outLen;
        ct.truncate(total);

        QVector<unsigned char> tag(kTagBytes);
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, kTagBytes, tag.data()) != 1)
            break;

        // Layout: iv || ciphertext || tag
        result = QByteArray(reinterpret_cast<const char *>(iv.data()), kIvBytes);
        result += ct;
        result += QByteArray(reinterpret_cast<const char *>(tag.data()), kTagBytes);
        ok = true;
    } while (false);

    EVP_CIPHER_CTX_free(ctx);

    if (!ok)
        return fallback;
    return QString::fromLatin1(kEncPrefix) + QString::fromLatin1(result.toBase64());
}

QString aesDecrypt(const QByteArray &blob)
{
    const QByteArray key = loadOrGenerateKey();
    if (key.size() != kKeyBytes || blob.size() < kIvBytes + kTagBytes)
        return {};

    const auto *iv  = reinterpret_cast<const unsigned char *>(blob.constData());
    const int ctLen = blob.size() - kIvBytes - kTagBytes;
    const auto *ct  = reinterpret_cast<const unsigned char *>(blob.constData() + kIvBytes);
    const auto *tag = reinterpret_cast<const unsigned char *>(blob.constData() + kIvBytes + ctLen);

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return {};

    QByteArray pt;
    bool ok = false;
    do {
        if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1)
            break;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, kIvBytes, nullptr) != 1)
            break;
        if (EVP_DecryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               iv) != 1)
            break;

        QByteArray out(ctLen + EVP_MAX_BLOCK_LENGTH, Qt::Uninitialized);
        int outLen = 0;
        if (EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char *>(out.data()), &outLen,
                              ct, ctLen) != 1)
            break;
        int total = outLen;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, kTagBytes,
                                const_cast<unsigned char *>(tag)) != 1)
            break;
        if (EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + total,
                                &outLen) != 1)
            break; // tampered / wrong key — authentication failed
        total += outLen;
        out.truncate(total);
        pt = out;
        ok = true;
    } while (false);

    EVP_CIPHER_CTX_free(ctx);
    if (!ok)
        return {};
    return QString::fromUtf8(pt);
}

} // namespace

QString encrypt(const QString &plain)
{
    if (plain.isEmpty())
        return {};
    return aesEncrypt(plain);
}

QString decrypt(const QString &cipher)
{
    if (cipher.isEmpty())
        return {};
    if (cipher.startsWith(QLatin1String(kEncPrefix))) {
        const QByteArray blob = QByteArray::fromBase64(
            cipher.mid(QLatin1String(kEncPrefix).size()).toLatin1());
        const QString pt = aesDecrypt(blob);
        if (!pt.isEmpty())
            return pt;
        // Không giải được (sai key / blob hỏng) — không rơi về Base64 vì đây
        // thực sự là mật bản AES, tránh trả về chuỗi rác.
        qWarning() << "Crypto: AES-GCM decrypt failed";
        return {};
    }
    // Legacy Base64 obfuscation — đọc trong suốt để tương thích dữ liệu cũ.
    return legacyDecrypt(cipher);
}

bool isEncrypted(const QString &cipher)
{
    return cipher.startsWith(QLatin1String(kEncPrefix));
}

} // namespace Crypto
