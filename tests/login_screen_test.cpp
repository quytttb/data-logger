#include "core/AuthService.h"
#include "data/db/Database.h"
#include "ThemeSetup.h"

#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QtTest>

Q_IMPORT_QML_PLUGIN(DataLogger_CorePlugin)
Q_IMPORT_QML_PLUGIN(LoggerKit_ThemePlugin)
Q_IMPORT_QML_PLUGIN(LoggerKit_ComponentsPlugin)

class LoginScreenTest : public QObject {
    Q_OBJECT

private slots:
    void createFirstAdminOnKiosk()
    {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        QVERIFY(Database::init(temp.filePath(QStringLiteral("login-screen.db"))));

        AuthService backendAuth;
        AuthService::setInstance(&backendAuth);
        QVERIFY(backendAuth.firstRun());

        QQmlEngine engine;
        QQmlComponent component(&engine, QUrl::fromLocalFile(QStringLiteral(LOGIN_SCREEN_QML_PATH)));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));

        QObject *theme = engine.singletonInstance<QObject *>(
            qmlTypeId("LoggerKit.Theme", 1, 0, "ThemeMode"));
        QVERIFY(theme);
        QVERIFY(theme->setProperty("mode", QStringLiteral("dark")));
        QVERIFY(theme->setProperty("touch", true));

        auto *auth = qobject_cast<AuthService *>(engine.singletonInstance<QObject *>(
            qmlTypeId("DataLogger.Core", 1, 0, "AuthService")));
        QVERIFY(auth);
        QCOMPARE(auth, &backendAuth);
        QVERIFY(auth->firstRun());

        QQuickWindow window;
        window.resize(1024, 600);
        auto *screen = qobject_cast<QQuickItem *>(component.create());
        QVERIFY2(screen, qPrintable(component.errorString()));
        QVERIFY(!screen->isVisible());
        QVERIFY(screen->setProperty("requested", true));
        screen->setParent(window.contentItem());
        screen->setParentItem(window.contentItem());
        screen->setSize(QSizeF(1024, 600));
        window.show();
        window.requestActivate();

        auto *flick = screen->findChild<QQuickItem *>(QStringLiteral("loginFlick"));
        auto *card = screen->findChild<QQuickItem *>(QStringLiteral("loginCard"));
        auto *username = screen->findChild<QQuickItem *>(QStringLiteral("setupUsername"));
        auto *displayName = screen->findChild<QQuickItem *>(QStringLiteral("setupDisplayName"));
        auto *password = screen->findChild<QQuickItem *>(QStringLiteral("setupPassword"));
        auto *confirm = screen->findChild<QQuickItem *>(QStringLiteral("setupConfirm"));
        auto *cancel = screen->findChild<QQuickItem *>(QStringLiteral("setupCancelButton"));
        auto *create = screen->findChild<QQuickItem *>(QStringLiteral("setupCreateButton"));
        QVERIFY(flick && card && username && displayName && password && confirm && cancel && create);
        QTRY_VERIFY(create->width() > 0);
        QTRY_COMPARE(username->width(), password->width());

        // Các cặp nằm cùng cột, hai cột ngang nhau và nút không cần cuộn.
        const auto position = [screen](QQuickItem *item) {
            return item->mapToItem(screen, QPointF());
        };
        QCOMPARE(card->width(), 720.0);
        QCOMPARE(position(username).x(), position(displayName).x());
        QCOMPARE(position(password).x(), position(confirm).x());
        QVERIFY(position(username).x() < position(password).x());
        QCOMPARE(position(username).y(), position(password).y());
        QCOMPARE(position(displayName).y(), position(confirm).y());
        QVERIFY(create->height() >= 48);
        QVERIFY(position(create).y() + create->height() <= 600);
        QCOMPARE(flick->property("contentY").toReal(), 0.0);

        // Nút và Enter vẫn kiểm tra đầu vào, chuyển focus đúng thứ tự rồi tạo admin.
        QSignalSpy cancelled(screen, SIGNAL(cancelRequested()));
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier,
                          position(cancel).toPoint() + QPoint(cancel->width() / 2,
                                                              cancel->height() / 2));
        QCOMPARE(cancelled.count(), 1);
        QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier,
                          position(create).toPoint() + QPoint(create->width() / 2,
                                                              create->height() / 2));
        QCOMPARE(screen->property("messageText").toString(), QStringLiteral("Enter a username."));
        QVERIFY(auth->firstRun());

        username->forceActiveFocus();
        QVERIFY(username->setProperty("text", QStringLiteral("admin")));
        QTest::keyClick(&window, Qt::Key_Return);
        QTRY_VERIFY(displayName->hasActiveFocus());
        QVERIFY(displayName->setProperty("text", QStringLiteral("Administrator")));
        QTest::keyClick(&window, Qt::Key_Return);
        QTRY_VERIFY(password->hasActiveFocus());
        QVERIFY(password->setProperty("text", QStringLiteral("admin1234")));
        QTest::keyClick(&window, Qt::Key_Return);
        QTRY_VERIFY(confirm->hasActiveFocus());
        QVERIFY(confirm->setProperty("text", QStringLiteral("mismatch123")));
        QTest::keyClick(&window, Qt::Key_Return);
        QCOMPARE(screen->property("messageText").toString(),
                 QStringLiteral("Passwords do not match."));
        QVERIFY(auth->firstRun());

        confirm->forceActiveFocus();
        QTRY_VERIFY(confirm->hasActiveFocus());
        QVERIFY(confirm->setProperty("text", QStringLiteral("admin1234")));
        QTest::keyClick(&window, Qt::Key_Return);
        QVERIFY2(auth->busy() || auth->authenticated(),
                 qPrintable(screen->property("messageText").toString()));
        QVERIFY(QTest::qWaitFor([auth]() { return !auth->busy(); }, 90000));
        QVERIFY2(auth->authenticated(), qPrintable(screen->property("messageText").toString()));
        QVERIFY(!auth->firstRun());
        QCOMPARE(auth->currentUsername(), QStringLiteral("admin"));
        QCOMPARE(auth->currentDisplayName(), QStringLiteral("Administrator"));
        QCOMPARE(auth->currentRole(), QStringLiteral("admin"));
        QVERIFY(AuthService::authorize(Permission::ConfigureSystem));
        QCOMPARE(password->property("text").toString(), QString());
        QCOMPARE(confirm->property("text").toString(), QString());
        AuthService::setInstance(nullptr);
    }
};

int main(int argc, char **argv)
{
    LoggerKit::Theme::applyQuickControlsStyle();
    QGuiApplication app(argc, argv);
    const int fontId = QFontDatabase::addApplicationFont(QStringLiteral(LOGIN_SCREEN_FONT_PATH));
    if (fontId >= 0) {
        const QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        if (!families.isEmpty())
            app.setFont(QFont(families.constFirst()));
    }
    LoginScreenTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "login_screen_test.moc"
