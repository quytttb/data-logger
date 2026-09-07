#include "utils/system/TimezoneOptions.h"

#include <QtTest>
#include <QCoreApplication>

// Bảng timezone là single source of truth cho dropdown Settings,
// migration DB legacy và lookup index — test khóa số lượng, ánh xạ
// Etc/GMT đảo dấu và fallback, tránh drift khi thêm/sửa múi giờ.
class TestTimezoneOptions : public QObject
{
    Q_OBJECT

private slots:
    void tableShape()
    {
        const auto list = TimezoneOptions::entries();
        QCOMPARE(list.size(), 26);
        QCOMPARE(list.first().first, QStringLiteral("UTC-12"));
        QCOMPARE(list.first().second, QStringLiteral("Etc/GMT+12"));
        QCOMPARE(list.last().first, QStringLiteral("UTC+12"));
        QCOMPARE(list.last().second, QStringLiteral("Etc/GMT-12"));
    }

    void invertedEtcGmtSign()
    {
        QCOMPARE(TimezoneOptions::indexOf(QStringLiteral("Etc/GMT-7")), 20);
        QCOMPARE(TimezoneOptions::indexOf(QStringLiteral("Etc/GMT")), 12);
        QCOMPARE(TimezoneOptions::indexOf(QStringLiteral("Asia/Kolkata")), 18);
        QCOMPARE(TimezoneOptions::indexOf(QStringLiteral("UTC+7")), -1); // legacy label, không phải IANA
    }

    void utcAliasNormalization()
    {
        QCOMPARE(TimezoneOptions::normalizeAlias(QStringLiteral("UTC")), QStringLiteral("Etc/GMT"));
        QCOMPARE(TimezoneOptions::normalizeAlias(QStringLiteral("Etc/UTC")), QStringLiteral("Etc/GMT"));
        QCOMPARE(TimezoneOptions::normalizeAlias(QStringLiteral("GMT")), QStringLiteral("Etc/GMT"));
        QCOMPARE(TimezoneOptions::normalizeAlias(QStringLiteral("Etc/GMT-7")),
                 QStringLiteral("Etc/GMT-7"));
    }

    void modelWithKnownSystemHasNoExtraRow()
    {
        const QVariantList model = TimezoneOptions::modelWithSystem(QStringLiteral("Etc/GMT-7"));
        QCOMPARE(model.size(), 26);
        QCOMPARE(model.at(20).toMap().value(QStringLiteral("label")).toString(),
                 QStringLiteral("UTC+7"));
    }

    void modelWithUnknownSystemPrependsEntry()
    {
        const QVariantList model =
            TimezoneOptions::modelWithSystem(QStringLiteral("Asia/Ho_Chi_Minh"));
        QCOMPARE(model.size(), 27);
        QCOMPARE(model.first().toMap().value(QStringLiteral("value")).toString(),
                 QStringLiteral("Asia/Ho_Chi_Minh"));
        QVERIFY(model.first().toMap().value(QStringLiteral("label")).toString()
                    .startsWith(QStringLiteral("System (")));
    }
};

QTEST_MAIN(TestTimezoneOptions)
#include "timezone_options_test.moc"
