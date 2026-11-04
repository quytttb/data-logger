#include "data/db/Database.h"
#include "data/repositories/AuditLogDao.h"
#include "data/repositories/UserAccountDao.h"
#include "utils/security/PasswordHasher.h"

#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
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

QDateTime utc(const char *iso)
{
    return QDateTime::fromString(QString::fromLatin1(iso), Qt::ISODateWithMs);
}

UserAccount makeUser(const QString &username, UserRole role)
{
    UserAccount user;
    user.username = username;
    user.role = role;
    user.passwordHash = PasswordHasher::hash(QStringLiteral("test-password"), {1000, 16, 32});
    return user;
}

} // namespace

// Slice 0: schema RBAC/audit, UserAccountDao và AuditLogDao.
class AuthDataTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tempDir.isValid());
        m_dbPath = m_tempDir.path() + QStringLiteral("/auth-test.db");
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

    void schemaHasVersionedTables()
    {
        ScopedDbConnection db;
        QSqlQuery query(db);

        QVERIFY(query.exec(QStringLiteral("PRAGMA user_version")));
        QVERIFY(query.next());
        QCOMPARE(query.value(0).toInt(), Database::kSchemaVersion);

        const QStringList tables {
            QStringLiteral("user_account"),
            QStringLiteral("audit_log"),
            QStringLiteral("calibration_session"),
            QStringLiteral("calibration_point"),
        };
        for (const QString &table : tables) {
            QSqlQuery exists(db);
            exists.prepare(QStringLiteral(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=:name"));
            exists.bindValue(QStringLiteral(":name"), table);
            QVERIFY2(exists.exec(), qPrintable(exists.lastError().text()));
            QVERIFY2(exists.next(), qPrintable(QStringLiteral("missing table ") + table));
        }

        QSqlQuery fk(db);
        QVERIFY(fk.exec(QStringLiteral("PRAGMA foreign_keys")));
        QVERIFY(fk.next());
        QCOMPARE(fk.value(0).toInt(), 1);
    }

    void reinitPreservesExistingData()
    {
        {
            ScopedDbConnection db;
            QSqlQuery insert(db);
            QVERIFY(insert.exec(QStringLiteral(
                "INSERT INTO sensor (name, slave_id, register_address) VALUES ('S1', 1, 0)")));
        }

        closeAllConnections();
        QVERIFY(Database::init(m_dbPath));

        ScopedDbConnection db;
        QSqlQuery query(db);
        QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM sensor")));
        QVERIFY(query.next());
        QCOMPARE(query.value(0).toInt(), 1);

        QVERIFY(query.exec(QStringLiteral("PRAGMA user_version")));
        QVERIFY(query.next());
        QCOMPARE(query.value(0).toInt(), Database::kSchemaVersion);
    }

    void userCrudAndCaseInsensitiveUsername()
    {
        ScopedDbConnection db;
        UserAccountDao dao(db);

        UserAccount admin = makeUser(QStringLiteral("Admin"), UserRole::Admin);
        QVERIFY(dao.insert(admin));
        QVERIFY(admin.id > 0);
        QVERIFY(admin.createdAt.isValid());
        QVERIFY(admin.updatedAt.isValid());

        const auto found = dao.findByUsername(QStringLiteral("admin"));
        QVERIFY(found.has_value());
        QCOMPARE(found->id, admin.id);
        QCOMPARE(found->role, UserRole::Admin);
        QCOMPARE(found->displayName, QStringLiteral("Admin"));

        UserAccount duplicate = makeUser(QStringLiteral("ADMIN"), UserRole::Viewer);
        QVERIFY(!dao.insert(duplicate));

        admin.displayName = QStringLiteral("Quản trị");
        admin.role = UserRole::Operator;
        admin.active = false;
        QVERIFY(dao.update(admin));

        const auto updated = dao.findById(admin.id);
        QVERIFY(updated.has_value());
        QCOMPARE(updated->displayName, QStringLiteral("Quản trị"));
        QCOMPARE(updated->role, UserRole::Operator);
        QVERIFY(!updated->active);

        QVERIFY(dao.usernameExists(QStringLiteral("admin")));
        QVERIFY(!dao.usernameExists(QStringLiteral("admin"), admin.id));
        QVERIFY(dao.setActive(admin.id, true));
        const auto reactivated = dao.findById(admin.id);
        QVERIFY(reactivated.has_value());
        QVERIFY(reactivated->active);
    }

    void loginStateAndAdminCount()
    {
        ScopedDbConnection db;
        UserAccountDao dao(db);

        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(dao.insert(admin));
        QCOMPARE(dao.countActiveAdmins(), 1);

        const QDateTime lockedUntil = QDateTime::currentDateTimeUtc().addSecs(60);
        QVERIFY(dao.updateLoginState(admin.id, 5, lockedUntil));
        auto found = dao.findById(admin.id);
        QVERIFY(found.has_value());
        QCOMPARE(found->failedAttempts, 5);
        QVERIFY(found->lockedUntil.isValid());
        QVERIFY(qAbs(found->lockedUntil.secsTo(lockedUntil)) <= 1);

        QVERIFY(dao.recordLoginSuccess(admin.id));
        found = dao.findById(admin.id);
        QVERIFY(found.has_value());
        QCOMPARE(found->failedAttempts, 0);
        QVERIFY(!found->lockedUntil.isValid());
        QVERIFY(found->lastLoginAt.isValid());

        QVERIFY(dao.setActive(admin.id, false));
        QCOMPARE(dao.countActiveAdmins(), 0);
    }

    void updateDetailsAndRemove()
    {
        ScopedDbConnection db;
        UserAccountDao dao(db);
        UserAccount user = makeUser(QStringLiteral("operator"), UserRole::Viewer);
        QVERIFY(dao.insert(user));
        QVERIFY(dao.updateLoginState(user.id, 3, QDateTime::currentDateTimeUtc().addSecs(60)));
        QVERIFY(dao.updateDetails(user.id, QStringLiteral(" New name "), UserRole::Operator, false));
        const auto stored = dao.findById(user.id);
        QVERIFY(stored.has_value());
        QCOMPARE(stored->displayName, QStringLiteral("New name"));
        QCOMPARE(stored->role, UserRole::Operator);
        QVERIFY(!stored->active);
        QCOMPARE(stored->passwordHash, user.passwordHash);
        QCOMPARE(stored->failedAttempts, 3);
        QVERIFY(stored->lockedUntil.isValid());
        QVERIFY(!dao.updateDetails(user.id, QStringLiteral("  "), UserRole::Viewer, true));
        QVERIFY(dao.remove(user.id));
        QVERIFY(!dao.findById(user.id).has_value());
        QVERIFY(!dao.remove(user.id));
    }

    void auditAppendQueryAndPurge()
    {
        ScopedDbConnection db;
        AuditLogDao dao(db);

        // actor_user_id có FK tới user_account — tạo user trước khi ghi log.
        QSqlQuery users(db);
        QVERIFY(users.exec(QStringLiteral(
            "INSERT INTO user_account (id, username, display_name, role, password_hash) VALUES "
            "(42, 'operator1', 'Người vận hành', 'operator', 'x'),"
            "(43, 'viewer1', 'Chỉ xem', 'viewer', 'x')")));

        const QDateTime base = utc("2026-01-01T00:00:00.000Z");

        AuditLogEntry login;
        login.occurredAt = base;
        login.actorKind = AuditActorKind::Local;
        login.actorUserId = 42;
        login.actorUsername = QStringLiteral("operator1");
        login.actorDisplayName = QStringLiteral("Người vận hành");
        login.action = QStringLiteral("auth.login");
        login.entity = QStringLiteral("user");
        login.entityId = QStringLiteral("42");
        login.result = AuditResult::Ok;
        login.detailJson = QStringLiteral(R"({"result":"ok"})");
        QVERIFY(dao.append(login));
        QVERIFY(login.id > 0);

        AuditLogEntry denied;
        denied.occurredAt = base.addSecs(3600);
        denied.actorKind = AuditActorKind::Local;
        denied.actorUserId = 43;
        denied.actorUsername = QStringLiteral("viewer1");
        denied.actorDisplayName = QStringLiteral("Chỉ xem");
        denied.action = QStringLiteral("sensor.update");
        denied.entity = QStringLiteral("sensor");
        denied.entityId = QStringLiteral("7");
        denied.result = AuditResult::Denied;
        QVERIFY(dao.append(denied));

        AuditLogEntry system;
        system.occurredAt = base.addSecs(7200);
        system.actorKind = AuditActorKind::System;
        system.action = QStringLiteral("system.start");
        system.entity = QStringLiteral("system");
        QVERIFY(dao.append(system));

        AuditLogQuery all;
        QCOMPARE(dao.count(all), 3);
        const QList<AuditLogEntry> newestFirst = dao.query(all);
        QCOMPARE(newestFirst.size(), 3);
        QCOMPARE(newestFirst.first().action, QStringLiteral("system.start"));

        AuditLogQuery byAction;
        byAction.actionPrefix = QStringLiteral("auth.");
        QCOMPARE(dao.count(byAction), 1);
        QCOMPARE(dao.query(byAction).first().actorUsername, QStringLiteral("operator1"));

        AuditLogQuery byEntity;
        byEntity.entity = QStringLiteral("sensor");
        QCOMPARE(dao.count(byEntity), 1);
        QCOMPARE(dao.query(byEntity).first().result, AuditResult::Denied);

        AuditLogQuery byResult;
        byResult.result = AuditResult::Denied;
        QCOMPARE(dao.count(byResult), 1);

        AuditLogQuery byRange;
        byRange.from = base.addSecs(1800);
        byRange.to = base.addSecs(5400);
        QCOMPARE(dao.count(byRange), 1);
        QCOMPARE(dao.query(byRange).first().action, QStringLiteral("sensor.update"));

        AuditLogQuery paged;
        paged.limit = 1;
        paged.offset = 1;
        const QList<AuditLogEntry> second = dao.query(paged);
        QCOMPARE(second.size(), 1);
        QCOMPARE(second.first().action, QStringLiteral("sensor.update"));

        QCOMPARE(dao.purgeBefore(base.addSecs(5400)), 2);
        QCOMPARE(dao.count(all), 1);
        QCOMPARE(dao.query(all).first().action, QStringLiteral("system.start"));
    }

    void auditAppendRollsBackWithCallerTransaction()
    {
        ScopedDbConnection db;
        AuditLogDao dao(db);

        AuditLogEntry entry;
        entry.action = QStringLiteral("sensor.update");
        entry.entity = QStringLiteral("sensor");
        entry.entityId = QStringLiteral("1");

        QVERIFY(db.get().transaction());
        QVERIFY(dao.append(entry));
        QVERIFY(db.get().rollback());

        QCOMPARE(dao.count(AuditLogQuery {}), 0);
    }

    void auditRejectsEmptyAction()
    {
        ScopedDbConnection db;
        AuditLogDao dao(db);
        AuditLogEntry entry;
        entry.entity = QStringLiteral("sensor");
        QVERIFY(!dao.append(entry));
        QCOMPARE(dao.count(AuditLogQuery {}), 0);
    }

private:
    QTemporaryDir m_tempDir;
    QString m_dbPath;
};

QTEST_MAIN(AuthDataTest)
#include "auth_data_test.moc"
