#include "utils/system/LocaleOptions.h"

#include <QtTest>
#include <QCoreApplication>

// Bảng locale là single source of truth cho dropdown Settings (vi/en) và
// QLocale::setDefault() lúc boot — khép số lượng và thứ tự mặc định tránh drift.
class TestLocaleOptions : public QObject
{
    Q_OBJECT

private slots:
    void tableShape()
    {
        const auto list = LocaleOptions::entries();
        QCOMPARE(list.size(), 2);
        QCOMPARE(list.first().first, QStringLiteral("Tiếng Việt"));
        QCOMPARE(list.first().second, QStringLiteral("vi"));
        QCOMPARE(list.last().first, QStringLiteral("English"));
        QCOMPARE(list.last().second, QStringLiteral("en"));
    }

    void indexOf()
    {
        QCOMPARE(LocaleOptions::indexOf(QStringLiteral("vi")), 0);
        QCOMPARE(LocaleOptions::indexOf(QStringLiteral("en")), 1);
        QCOMPARE(LocaleOptions::indexOf(QStringLiteral("fr")), -1);
        QCOMPARE(LocaleOptions::indexOf(QString()), -1);
    }

    void modelShape()
    {
        const QVariantList model = LocaleOptions::model();
        QCOMPARE(model.size(), 2);
        QCOMPARE(model.at(0).toMap().value(QStringLiteral("label")).toString(),
                 QStringLiteral("Tiếng Việt"));
        QCOMPARE(model.at(0).toMap().value(QStringLiteral("value")).toString(),
                 QStringLiteral("vi"));
        QCOMPARE(model.at(1).toMap().value(QStringLiteral("value")).toString(),
                 QStringLiteral("en"));
    }
};

QTEST_MAIN(TestLocaleOptions)
#include "locale_options_test.moc"
