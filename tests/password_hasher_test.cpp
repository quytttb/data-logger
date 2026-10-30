#include "utils/security/PasswordHasher.h"

#include <QtTest>

// Khóa hành vi KDF: vector PBKDF2 chuẩn, salt ngẫu nhiên, định dạng có version,
// so sánh constant-time (gián tiếp qua verify), chống chuỗi băm hỏng.
class TestPasswordHasher : public QObject {
    Q_OBJECT

private slots:
    void deriveKeyKnownVectors()
    {
        // Vector PBKDF2-HMAC-SHA256 (password="password", salt="salt", dkLen=32).
        const QByteArray password("password");
        const QByteArray salt("salt");

        QCOMPARE(PasswordHasher::deriveKey(password, salt, 1, 32).toHex(),
                 QByteArray("120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"));
        QCOMPARE(PasswordHasher::deriveKey(password, salt, 2, 32).toHex(),
                 QByteArray("ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"));
        QCOMPARE(PasswordHasher::deriveKey(password, salt, 4096, 32).toHex(),
                 QByteArray("c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"));
    }

    void hashAndVerify()
    {
        const PasswordHasher::Params params {1000, 16, 32};
        const QString encoded = PasswordHasher::hash(QStringLiteral("S3cret!öüñ"), params);

        QVERIFY(!encoded.isEmpty());
        QVERIFY(encoded.startsWith(QStringLiteral("pbkdf2-sha256$1000$")));
        QVERIFY(!encoded.contains(QStringLiteral("S3cret")));
        QVERIFY(PasswordHasher::verify(QStringLiteral("S3cret!öüñ"), encoded));
        QVERIFY(!PasswordHasher::verify(QStringLiteral("S3cret!öü"), encoded));
        QVERIFY(!PasswordHasher::verify(QString(), encoded));

        bool needsRehash = false;
        QVERIFY(PasswordHasher::verify(QStringLiteral("S3cret!öüñ"), encoded, &needsRehash));
        QVERIFY(needsRehash);  // 1000 vòng yếu hơn mặc định
    }

    void defaultParamsDoNotNeedRehash()
    {
        const QString encoded = PasswordHasher::hash(QStringLiteral("mat-khau-dai-2026"));
        QVERIFY(encoded.startsWith(QStringLiteral("pbkdf2-sha256$600000$")));
        bool needsRehash = true;
        QVERIFY(PasswordHasher::verify(QStringLiteral("mat-khau-dai-2026"), encoded, &needsRehash));
        QVERIFY(!needsRehash);
    }

    void saltsAreUnique()
    {
        const PasswordHasher::Params params {1000, 16, 32};
        const QString first = PasswordHasher::hash(QStringLiteral("same-password"), params);
        const QString second = PasswordHasher::hash(QStringLiteral("same-password"), params);
        QVERIFY(first != second);
        QVERIFY(PasswordHasher::verify(QStringLiteral("same-password"), first));
        QVERIFY(PasswordHasher::verify(QStringLiteral("same-password"), second));
    }

    void unicodeNormalization()
    {
        // "café" dạng dựng sẵn (U+00E9) và dạng tổ hợp (e + U+0301) phải khớp.
        const QString composed = QString::fromUtf8("caf\xc3\xa9");
        const QString decomposed = QString::fromUtf8("cafe\xcc\x81");
        const QString encoded = PasswordHasher::hash(composed, {1000, 16, 32});
        QVERIFY(PasswordHasher::verify(decomposed, encoded));
    }

    void rejectsMalformedHashes()
    {
        QVERIFY(!PasswordHasher::verify(QStringLiteral("x"), QString()));
        QVERIFY(!PasswordHasher::verify(QStringLiteral("x"), QStringLiteral("plain-text")));
        QVERIFY(!PasswordHasher::verify(QStringLiteral("x"), QStringLiteral("pbkdf2-sha256$0$c2FsdA==$aGFzaA==")));
        QVERIFY(!PasswordHasher::verify(QStringLiteral("x"), QStringLiteral("pbkdf2-sha256$1000$$")));
        QVERIFY(!PasswordHasher::verify(QStringLiteral("x"), QStringLiteral("argon2id$1$c2FsdA==$aGFzaA==")));
    }

    void rejectsInvalidParams()
    {
        QVERIFY(PasswordHasher::hash(QString()).isEmpty());
        QVERIFY(PasswordHasher::hash(QStringLiteral("x"), {0, 16, 32}).isEmpty());
        QVERIFY(PasswordHasher::hash(QStringLiteral("x"), {1000, 4, 32}).isEmpty());
        QVERIFY(PasswordHasher::hash(QStringLiteral("x"), {1000, 16, 8}).isEmpty());
        QVERIFY(PasswordHasher::deriveKey(QByteArray(), "salt", 1, 32).isEmpty());
        QVERIFY(PasswordHasher::deriveKey("pw", QByteArray(), 1, 32).isEmpty());
    }
};

QTEST_APPLESS_MAIN(TestPasswordHasher)
#include "password_hasher_test.moc"
