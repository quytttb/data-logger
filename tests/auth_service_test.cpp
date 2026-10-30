#include "core/AuthService.h"
#include "data/db/Database.h"
#include "data/repositories/UserAccountDao.h"
#include "utils/security/PasswordHasher.h"

#include <QFile>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QTemporaryDir>
#include <QtTest>

namespace {

void closeAllConnections()
{
    const QStringList names = QSqlDatabase::connectionNames();
    for (const QString &name : names) {
        {
            QSqlDatabase db = QSqlDatabase::database(name, false);
            if (db.isOpen())
                db.close();
        }
    }
    for (const QString &name : names)
        QSqlDatabase::removeDatabase(name);
}

UserAccount makeUser(const QString &username, UserRole role,
                     bool mustChangePassword = false)
{
    UserAccount user;
    user.username = username;
    user.role = role;
    user.active = true;
    user.mustChangePassword = mustChangePassword;
    user.passwordHash = PasswordHasher::hash(QStringLiteral("test-password"));
    return user;
}

int insertUser(UserAccount &user)
{
    ScopedDbConnection db;
    UserAccountDao dao(db);
    return dao.insert(user) ? user.id : 0;
}

// Chờ tác vụ băm mật khẩu chạy xong trên thread pool. Timeout rộng vì CI
// có thể chậm hơn máy dev, nhưng vẫn phải fail nếu treo.
bool waitIdle(AuthService &auth)
{
    return QTest::qWaitFor([&auth]() { return !auth.busy(); }, 90000);
}

} // namespace

// Slice 1: AuthService — tạo admin đầu tiên, đăng nhập, khóa phiên, RBAC,
// đổi mật khẩu bắt buộc và bảo vệ admin cuối cùng.
class AuthServiceTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tempDir.isValid());
        m_dbPath = m_tempDir.path() + QStringLiteral("/auth-service-test.db");
    }

    void cleanupTestCase()
    {
        closeAllConnections();
    }

    void init()
    {
        closeAllConnections();
        QFile::remove(m_dbPath);
        QVERIFY(Database::init(m_dbPath));
    }

    void passwordPolicy()
    {
        QVERIFY(!AuthService::validatePassword("admin", QStringLiteral("short1")).isEmpty());
        QVERIFY(!AuthService::validatePassword("admin", QStringLiteral("allletters")).isEmpty());
        QVERIFY(!AuthService::validatePassword("admin", QStringLiteral("12345678")).isEmpty());
        QVERIFY(!AuthService::validatePassword("Admin", QStringLiteral("admin")).isEmpty());
        QCOMPARE(AuthService::validatePassword("admin", QStringLiteral("admin1234")), QString());
    }

    void firstRunCreatesAdmin()
    {
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(auth.firstRun());
        QCOMPARE(auth.userCount(), 0);
        QVERIFY(!AuthService::authorize(Permission::ManageUsers));

        QSignalSpy messages(&auth, &AuthService::messageSent);
        auth.createFirstAdmin(QStringLiteral("admin"), QStringLiteral("Administrator"),
                              QStringLiteral("admin1234"), QStringLiteral("admin1234"));
        QVERIFY(waitIdle(auth));

        QVERIFY(auth.authenticated());
        QVERIFY(!auth.firstRun());
        QCOMPARE(auth.userCount(), 1);
        QCOMPARE(auth.currentUsername(), QStringLiteral("admin"));
        QCOMPARE(auth.currentRole(), QStringLiteral("admin"));
        QVERIFY(auth.canManageUsers());
        QVERIFY(auth.canConfigureSensors());
        QVERIFY(AuthService::authorize(Permission::ManageUsers));
        QCOMPARE(int(messages.count()), 1);

        // Không lưu plaintext: cột password_hash phải là chuỗi PBKDF2.
        ScopedDbConnection db;
        UserAccountDao dao(db);
        const auto admin = dao.findByUsername(QStringLiteral("admin"));
        QVERIFY(admin.has_value());
        QVERIFY(admin->passwordHash.startsWith(QStringLiteral("pbkdf2-sha256$")));
        QVERIFY(!admin->passwordHash.contains(QStringLiteral("admin1234")));
    }

    void firstAdminRejectsMismatchedPassword()
    {
        AuthService auth;
        AuthService::setInstance(&auth);

        QSignalSpy messages(&auth, &AuthService::messageSent);
        auth.createFirstAdmin(QStringLiteral("admin"), QString(),
                              QStringLiteral("admin1234"), QStringLiteral("admin4321"));
        QCOMPARE(int(messages.count()), 1);
        QVERIFY(!auth.authenticated());
        QVERIFY(auth.firstRun());

        ScopedDbConnection db;
        UserAccountDao dao(db);
        QCOMPARE(dao.count(), 0);
    }

    void loginLocksAfterFiveFailures()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(!auth.firstRun());

        for (int attempt = 1; attempt <= AuthService::kMaxFailedAttemptsBeforeLock; ++attempt) {
            QSignalSpy messages(&auth, &AuthService::messageSent);
            auth.login(QStringLiteral("admin"), QStringLiteral("wrong-password"));
            QVERIFY(waitIdle(auth));
            QCOMPARE(int(messages.count()), 1);
            QVERIFY(!auth.authenticated());
        }

        {
            ScopedDbConnection db;
            UserAccountDao dao(db);
            const auto stored = dao.findByUsername(QStringLiteral("admin"));
            QVERIFY(stored.has_value());
            QCOMPARE(stored->failedAttempts, AuthService::kMaxFailedAttemptsBeforeLock);
            QVERIFY(stored->lockedUntil.isValid());
            QVERIFY(stored->lockedUntil
                    > QDateTime::currentDateTimeUtc().addSecs(-1));
        }

        // Đúng mật khẩu vẫn bị chặn trong thời gian khóa tạm thời.
        QSignalSpy messages(&auth, &AuthService::messageSent);
        auth.login(QStringLiteral("admin"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QCOMPARE(int(messages.count()), 1);
        QVERIFY(!auth.authenticated());
        QVERIFY(messages.first().at(1).toString().contains(QStringLiteral("Too many failed attempts"),
                                                           Qt::CaseInsensitive));
    }

    void operatorAndViewerPermissions()
    {
        UserAccount operatorUser = makeUser(QStringLiteral("operator"), UserRole::Operator);
        QVERIFY(insertUser(operatorUser) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(!auth.firstRun());

        auth.login(QStringLiteral("operator"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());

        QVERIFY(auth.canViewData());
        QVERIFY(auth.canRunTester());
        QVERIFY(auth.canCalibrate());
        QVERIFY(!auth.canConfigureSensors());
        QVERIFY(!auth.canConfigureSystem());
        QVERIFY(!auth.canManageUsers());
        QVERIFY(!auth.canViewAudit());
        QVERIFY(!AuthService::authorize(Permission::ConfigureSensors));
        QVERIFY(AuthService::authorize(Permission::RunTester));

        // Backend phải từ chối, không chỉ ẩn nút ở QML.
        QSignalSpy messages(&auth, &AuthService::messageSent);
        QVERIFY(auth.users().isEmpty());
        auth.createUser(QStringLiteral("other"), QString(), QStringLiteral("viewer"),
                        QStringLiteral("other1234"), QStringLiteral("other1234"));
        QCOMPARE(int(messages.count()), 1);
        QCOMPARE(messages.first().at(0).toString(), QStringLiteral("Permission denied"));

        ScopedDbConnection db;
        UserAccountDao dao(db);
        QCOMPARE(dao.count(), 1);
    }

    void loginThenLockAndUnlock()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);

        auth.login(QStringLiteral("admin"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());
        QVERIFY(!auth.locked());

        auth.lock();
        QVERIFY(auth.locked());
        QVERIFY(!auth.canViewData());
        QVERIFY(!AuthService::authorize(Permission::ViewData));
        // Không thể gọi đổi mật khẩu trực tiếp khi phiên đang khóa.
        auth.changePassword(QStringLiteral("test-password"), QStringLiteral("changed123"),
                            QStringLiteral("changed123"));
        QVERIFY(!auth.busy());

        auth.unlock(QStringLiteral("wrong-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.locked());
        QVERIFY(auth.authenticated());

        auth.unlock(QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(!auth.locked());
        QVERIFY(auth.canViewData());
        QVERIFY(AuthService::authorize(Permission::ViewData));

        auth.logout();
        QVERIFY(!auth.authenticated());
        QVERIFY(!AuthService::authorize(Permission::ViewData));
    }

    void forcedPasswordChangeAfterReset()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        auth.login(QStringLiteral("admin"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());

        auth.createUser(QStringLiteral("operator"), QStringLiteral("Operator One"),
                        QStringLiteral("operator"), QStringLiteral("initial123"),
                        QStringLiteral("initial123"));
        QVERIFY(waitIdle(auth));

        auth.logout();
        QVERIFY(!auth.authenticated());

        auth.login(QStringLiteral("operator"), QStringLiteral("initial123"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());
        QVERIFY(auth.mustChangePassword());
        // Chưa đổi mật khẩu thì không được dùng quyền operator.
        QVERIFY(auth.canViewData());
        QVERIFY(!auth.canRunTester());
        QVERIFY(!AuthService::authorize(Permission::RunTester));

        QSignalSpy messages(&auth, &AuthService::messageSent);
        auth.changePassword(QStringLiteral("wrong"), QStringLiteral("newpass123"),
                            QStringLiteral("newpass123"));
        QVERIFY(waitIdle(auth));
        QCOMPARE(int(messages.count()), 1);
        QVERIFY(auth.mustChangePassword());

        messages.clear();
        auth.changePassword(QStringLiteral("initial123"), QStringLiteral("newpass123"),
                            QStringLiteral("newpass123"));
        QVERIFY(waitIdle(auth));
        QCOMPARE(int(messages.count()), 1);
        QVERIFY(!auth.mustChangePassword());
        QVERIFY(auth.canRunTester());

        // Mật khẩu cũ không còn dùng được.
        auth.logout();
        auth.login(QStringLiteral("operator"), QStringLiteral("initial123"));
        QVERIFY(waitIdle(auth));
        QVERIFY(!auth.authenticated());

        auth.login(QStringLiteral("operator"), QStringLiteral("newpass123"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());
    }

    void lastAdminIsProtected()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        auth.login(QStringLiteral("admin"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());

        QVERIFY(!auth.setUserActive(admin.id, false));
        QVERIFY(!auth.setUserRole(admin.id, QStringLiteral("viewer")));

        ScopedDbConnection db;
        UserAccountDao dao(db);
        const auto stored = dao.findById(admin.id);
        QVERIFY(stored.has_value());
        QVERIFY(stored->active);
        QCOMPARE(userRoleToString(stored->role), QStringLiteral("admin"));
        QCOMPARE(dao.countActiveAdmins(), 1);
    }

    void adminManagesOtherAccounts()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        UserAccount target = makeUser(QStringLiteral("target"), UserRole::Viewer);
        QVERIFY(insertUser(admin) > 0);
        QVERIFY(insertUser(target) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        auth.login(QStringLiteral("admin"), QStringLiteral("test-password"));
        QVERIFY(waitIdle(auth));
        QVERIFY(auth.authenticated());

        const QVariantList users = auth.users();
        QCOMPARE(int(users.size()), 2);
        for (const QVariant &item : users) {
            const QVariantMap user = item.toMap();
            QVERIFY(!user.contains(QStringLiteral("passwordHash")));
            QVERIFY(!user.contains(QStringLiteral("password")));
        }

        QVERIFY(auth.setUserActive(target.id, false));
        {
            ScopedDbConnection db;
            UserAccountDao dao(db);
            const auto stored = dao.findById(target.id);
            QVERIFY(stored.has_value());
            QVERIFY(!stored->active);
        }

        QVERIFY(auth.setUserRole(target.id, QStringLiteral("operator")));
        {
            ScopedDbConnection db;
            UserAccountDao dao(db);
            const auto stored = dao.findById(target.id);
            QVERIFY(stored.has_value());
            QCOMPARE(userRoleToString(stored->role), QStringLiteral("operator"));
        }

        QVERIFY(auth.setUserActive(target.id, true));
        {
            ScopedDbConnection db;
            UserAccountDao dao(db);
            const auto stored = dao.findById(target.id);
            QVERIFY(stored.has_value());
            QVERIFY(stored->active);
        }
    }

private:
    QTemporaryDir m_tempDir;
    QString m_dbPath;
};

QTEST_GUILESS_MAIN(AuthServiceTest)

#include "auth_service_test.moc"
