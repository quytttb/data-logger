#include "utils/crypto/Crypto.h"

#include <QTemporaryDir>
#include <QtTest>

// Audit C1: Crypto phải là AES-256-GCM thật sự — round-trip, mật bản không
// chứa plaintext, chuỗi Base64 đời cũ vẫn đọc được (tương thích ngược).
class TestCrypto : public QObject
{
    Q_OBJECT

    QTemporaryDir m_tmpDir;

private slots:
    void initTestCase()
    {
        QVERIFY(m_tmpDir.isValid());
        // Khóa test nằm ngoài thư mục config thật của người dùng.
        qputenv("DATALOGGER_CONFIG_DIR", m_tmpDir.path().toUtf8());
    }

    void roundTrip()
    {
        const QString secret = QStringLiteral("s3cret-FTP-pass!öüñ");
        const QString enc = Crypto::encrypt(secret);
        QVERIFY(!enc.isEmpty());
        QVERIFY(enc != secret);
        QCOMPARE(Crypto::decrypt(enc), secret);
    }

    void ciphertextHidesPlaintext()
    {
        const QString secret = QStringLiteral("password123");
        const QString enc = Crypto::encrypt(secret);
        // Mật bản AES có tiền tố "enc1:"; Base64 của plaintext không được xuất hiện.
        QVERIFY(enc.startsWith(QStringLiteral("enc1:")));
        QVERIFY(!enc.contains(QString::fromLatin1(secret.toUtf8().toBase64())));
        QVERIFY(Crypto::isEncrypted(enc));
    }

    void legacyBase64StillDecrypts()
    {
        // Dữ liệu DB đời cũ (obfuscation Base64) không được vỡ khi giải.
        const QString plain = QStringLiteral("old-ftp-password");
        const QString legacy = QString::fromLatin1(plain.toUtf8().toBase64());
        QVERIFY(!Crypto::isEncrypted(legacy));
        QCOMPARE(Crypto::decrypt(legacy), plain);
    }

    void tamperedCiphertextFails()
    {
        const QString enc = Crypto::encrypt(QStringLiteral("payload"));
        QString tampered = enc;
        // Lật 1 ký tự trong vùng mật bản (sau tiền tố) — GCM phải từ chối.
        const int pos = tampered.size() - 3;
        tampered[pos] = (tampered[pos] == QLatin1Char('A')) ? QLatin1Char('B')
                                                            : QLatin1Char('A');
        QCOMPARE(Crypto::decrypt(tampered), QString());
    }

    void emptyRoundTrip()
    {
        QCOMPARE(Crypto::encrypt(QString()), QString());
        QCOMPARE(Crypto::decrypt(QString()), QString());
    }
};

QTEST_MAIN(TestCrypto)
#include "crypto_test.moc"
