#include "core/AuthService.h"
#include "core/KioskAccessController.h"
#include "data/db/Database.h"

#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class KioskAccessTest : public QObject {
    Q_OBJECT

private slots:
    void readOnlyViewsStayAvailable()
    {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        QVERIFY(Database::init(temp.filePath(QStringLiteral("kiosk-access.db"))));

        AuthService auth;
        AuthService::setInstance(&auth);
        KioskAccessController access;
        QSignalSpy authorized(&access, &KioskAccessController::actionAuthorized);

        // Chưa có admin, kể cả sau khởi động, vẫn xem/lọc được dữ liệu.
        QVERIFY(auth.firstRun());
        QCOMPARE(access.currentTab(), int(KioskAccessController::Monitor));
        QVERIFY(access.request(KioskAccessController::History));
        QVERIFY(access.request(KioskAccessController::Trending));
        QCOMPARE(access.currentTab(), int(KioskAccessController::Trending));
        QVERIFY(!access.authenticationRequested());

        // Chỉ yêu cầu tạo admin khi chủ động vào chức năng được bảo vệ.
        QVERIFY(!access.request(KioskAccessController::Settings));
        QVERIFY(access.authenticationRequested());
        QCOMPARE(access.currentTab(), int(KioskAccessController::Trending));
        access.cancelAuthentication();
        QVERIFY(!access.authenticationRequested());
        QCOMPARE(access.currentTab(), int(KioskAccessController::Trending));

        QVERIFY(!access.request(KioskAccessController::Settings));
        auth.createFirstAdmin(QStringLiteral("admin"), QStringLiteral("Administrator"),
                              QStringLiteral("admin1234"), QStringLiteral("admin1234"));
        QVERIFY(QTest::qWaitFor([&auth]() { return !auth.busy(); }, 90000));
        QVERIFY(auth.authenticated());
        QVERIFY(AuthService::authorize(Permission::ConfigureSystem));
        QVERIFY(!access.authenticationRequested());
        QCOMPARE(access.currentTab(), int(KioskAccessController::Settings));

        // Hết quyền khi đang xem History không chuyển trang và không bật login.
        QVERIFY(access.request(KioskAccessController::History));
        auth.lock();
        QVERIFY(auth.locked());
        QVERIFY(!AuthService::authorize(Permission::ConfigureSystem));
        QCOMPARE(access.currentTab(), int(KioskAccessController::History));
        QVERIFY(!access.authenticationRequested());
        QVERIFY(access.request(KioskAccessController::Trending));

        // Hiệu chuẩn yêu cầu xác thực, mở lại đúng thao tác sau khi unlock.
        QVERIFY(!access.request(KioskAccessController::Calibration));
        QVERIFY(access.authenticationRequested());
        QCOMPARE(access.currentTab(), int(KioskAccessController::Trending));
        auth.unlock(QStringLiteral("admin1234"));
        QVERIFY(QTest::qWaitFor([&auth]() { return !auth.busy(); }, 90000));
        QVERIFY(!auth.locked());
        QVERIFY(!access.authenticationRequested());
        QCOMPARE(authorized.constLast().constFirst().toInt(), int(KioskAccessController::Calibration));
        QCOMPARE(access.currentTab(), int(KioskAccessController::Trending));

        QVERIFY(access.request(KioskAccessController::Tester));
        auth.lock();
        // Hết quyền khi đang ở Tester trở về Monitor, không phủ màn hình.
        QCOMPARE(access.currentTab(), int(KioskAccessController::Monitor));
        QVERIFY(!access.authenticationRequested());
        QVERIFY(!access.request(KioskAccessController::Settings));
        QVERIFY(access.authenticationRequested());
        access.cancelAuthentication();
        auth.unlock(QStringLiteral("admin1234"));
        QVERIFY(QTest::qWaitFor([&auth]() { return !auth.busy(); }, 90000));
        QCOMPARE(access.currentTab(), int(KioskAccessController::Monitor));
        QVERIFY(!access.authenticationRequested());

        QVERIFY(!access.request(-1));
        QVERIFY(!access.request(99));
        AuthService::setInstance(nullptr);
    }
};

QTEST_GUILESS_MAIN(KioskAccessTest)
#include "kiosk_access_test.moc"
