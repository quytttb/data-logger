#include "core/AuditController.h"
#include "core/AuthService.h"
#include "core/SensorListModel.h"
#include "core/SettingsController.h"
#include "core/MonitorController.h"
#include "core/ReportController.h"
#include "data/db/Database.h"
#include "data/models/AppConfig.h"
#include "data/repositories/AuditLogDao.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/UserAccountDao.h"
#include "utils/security/PasswordHasher.h"
#include "network/modbus/ModbusTcpServerService.h"
#include "network/rest/RestApiService.h"

#include <QFile>
#include <QJsonDocument>
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

UserAccount makeUser(const QString &username, UserRole role)
{
    UserAccount user;
    user.username = username;
    user.displayName = username;
    user.role = role;
    user.active = true;
    user.passwordHash = PasswordHasher::hash(QStringLiteral("test-password"));
    return user;
}

int insertUser(UserAccount &user)
{
    ScopedDbConnection db;
    UserAccountDao dao(db);
    return dao.insert(user) ? user.id : 0;
}

bool waitIdle(AuthService &auth)
{
    return QTest::qWaitFor([&auth]() { return !auth.busy(); }, 90000);
}

bool login(AuthService &auth, const QString &username, const QString &password)
{
    auth.login(username, password);
    return waitIdle(auth);
}

QList<AuditLogEntry> auditEntries(const QString &actionPrefix)
{
    ScopedDbConnection db;
    AuditLogDao dao(db);
    AuditLogQuery query;
    query.actionPrefix = actionPrefix;
    return dao.query(query);
}

QVariantMap analogSensorProps()
{
    return QVariantMap{
        {QStringLiteral("name"), QStringLiteral("SO2")},
        {QStringLiteral("sensorSymbol"), QStringLiteral("SO2")},
        {QStringLiteral("unit"), QStringLiteral("mg/m3")},
        {QStringLiteral("slaveId"), 1},
        {QStringLiteral("registerAddress"), 10},
        {QStringLiteral("sensorType"), QStringLiteral("ANALOG")},
        {QStringLiteral("coefficient"), QStringLiteral("{\"a\":1,\"b\":0}")},
    };
}

} // namespace

// Slice 2: audit log — ghi trong transaction nghiệp vụ, chặn truy cập trái
// quyền và không lưu secret.
class AuditTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tempDir.isValid());
        m_dbPath = m_tempDir.path() + QStringLiteral("/audit-test.db");
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

    void sensorWriteIsAudited()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));
        QVERIFY(auth.authenticated());

        SensorListModel model(nullptr);
        QVERIFY(model.addSensor(analogSensorProps()));
        QCOMPARE(model.rowCount(), 1);

        const QList<AuditLogEntry> entries = auditEntries(QStringLiteral("sensor.add"));
        QCOMPARE(int(entries.size()), 1);
        const AuditLogEntry &entry = entries.first();
        QCOMPARE(auditResultToString(entry.result), QStringLiteral("ok"));
        QCOMPARE(entry.entity, QStringLiteral("sensor"));
        QCOMPARE(entry.actorUsername, QStringLiteral("admin"));
        QVERIFY(entry.entityId.toInt() > 0);
        QVERIFY(entry.detailJson.contains(QStringLiteral("SO2")));

        // Ghi audit nằm trong cùng transaction và không đụng tới secret.
        QVERIFY(!entry.detailJson.contains(QStringLiteral("password"), Qt::CaseInsensitive));
    }

    void deniedWriteIsAudited()
    {
        UserAccount viewer = makeUser(QStringLiteral("viewer"), UserRole::Viewer);
        QVERIFY(insertUser(viewer) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("viewer"), QStringLiteral("test-password")));
        QVERIFY(auth.authenticated());

        SensorListModel model(nullptr);
        QVERIFY(!model.addSensor(analogSensorProps()));
        QCOMPARE(model.rowCount(), 0);

        const QList<AuditLogEntry> entries = auditEntries(QStringLiteral("sensor.add"));
        QCOMPARE(int(entries.size()), 1);
        QCOMPARE(auditResultToString(entries.first().result), QStringLiteral("denied"));
        QCOMPARE(entries.first().actorUsername, QStringLiteral("viewer"));

        ScopedDbConnection db;
        SensorDao dao(db);
        QVERIFY(dao.loadAll().isEmpty());
    }

    void advancedCoefficientIsNotCopiedToAudit()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));

        SensorListModel model(nullptr);
        QVariantMap props = analogSensorProps();
        props[QStringLiteral("coefficient")] = QStringLiteral("{\"token\":\"secret-one\"}");
        QVERIFY(model.addSensor(props));
        const int id = model.sensorAt(0).value(QStringLiteral("sensorId")).toInt();
        props[QStringLiteral("coefficient")] = QStringLiteral("{\"password\":\"secret-two\"}");
        QVERIFY(model.updateSensor(id, props));

        const auto creates = auditEntries(QStringLiteral("sensor.add"));
        const auto updates = auditEntries(QStringLiteral("sensor.update"));
        QCOMPARE(creates.size(), 1);
        QCOMPARE(updates.size(), 1);
        QVERIFY(!creates.first().detailJson.contains(QStringLiteral("secret-one")));
        QVERIFY(!updates.first().detailJson.contains(QStringLiteral("secret-one")));
        QVERIFY(!updates.first().detailJson.contains(QStringLiteral("secret-two")));
        QVERIFY(updates.first().detailJson.contains(QStringLiteral("coefficientChanged")));
    }

    void failedWriteLeavesNoAudit()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));

        SensorListModel model(nullptr);
        QVERIFY(!model.removeSensor(999999));
        QVERIFY(auditEntries(QStringLiteral("sensor.delete")).isEmpty());
    }

    void loginFailuresAndLogoutAreAudited()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("wrong-password")));
        QVERIFY(!auth.authenticated());
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));
        QVERIFY(auth.authenticated());
        auth.logout();
        QVERIFY(!auth.authenticated());

        const QList<AuditLogEntry> logins = auditEntries(QStringLiteral("auth.login"));
        QCOMPARE(int(logins.size()), 2);
        // query() sắp xếp mới nhất trước: [0] thành công, [1] thất bại.
        QCOMPARE(auditResultToString(logins.at(0).result), QStringLiteral("ok"));
        QCOMPARE(auditResultToString(logins.at(1).result), QStringLiteral("failed"));
        QVERIFY(logins.at(1).detailJson.contains(QStringLiteral("wrong_password")));
        // Không bao giờ lưu mật khẩu người dùng vừa gõ.
        QVERIFY(!logins.at(1).detailJson.contains(QStringLiteral("wrong-password")));

        QCOMPARE(int(auditEntries(QStringLiteral("auth.logout")).size()), 1);
    }

    void accountAuditHidesSecrets()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));

        QSignalSpy messages(&auth, &AuthService::messageSent);
        auth.createUser(QStringLiteral("operator"), QStringLiteral("Operator"),
                        QStringLiteral("operator"), QStringLiteral("initial123"),
                        QStringLiteral("initial123"));
        QVERIFY(waitIdle(auth));
        QVERIFY(!messages.isEmpty());

        const QList<AuditLogEntry> entries = auditEntries(QStringLiteral("user.create"));
        QCOMPARE(int(entries.size()), 1);
        const QString detail = entries.first().detailJson;
        QVERIFY(detail.contains(QStringLiteral("operator")));
        QVERIFY(detail.contains(QStringLiteral("mustChangePassword")));
        QVERIFY(!detail.contains(QStringLiteral("initial123")));
        QVERIFY(!detail.contains(QStringLiteral("pbkdf2"), Qt::CaseInsensitive));
        QVERIFY(!detail.contains(QStringLiteral("passwordHash")));
    }

    void auditViewerIsDenied()
    {
        UserAccount viewer = makeUser(QStringLiteral("viewer"), UserRole::Viewer);
        QVERIFY(insertUser(viewer) > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("viewer"), QStringLiteral("test-password")));

        AuditController controller;
        controller.refresh();
        QCOMPARE(controller.total(), 0);
        QVERIFY(controller.entries().isEmpty());
    }

    void settingsAuditWhitelistHidesSecrets()
    {
        AppConfig before;
        before.stationName = QStringLiteral("Old station");
        before.ftpPassword = QStringLiteral("enc-secret-1");
        before.restApiToken = QStringLiteral("token-111");

        AppConfig after = before;
        after.stationName = QStringLiteral("New station");
        after.ftpPassword = QStringLiteral("enc-secret-2");
        after.restApiToken = QStringLiteral("token-222");

        const QJsonObject detail = SettingsController::auditChanges(before, after);
        const QString json = QString::fromUtf8(
            QJsonDocument(detail).toJson(QJsonDocument::Compact));

        QVERIFY(json.contains(QStringLiteral("stationName")));
        QVERIFY(json.contains(QStringLiteral("New station")));
        QVERIFY(!json.contains(QStringLiteral("ftpPassword")));
        QVERIFY(!json.contains(QStringLiteral("restApiToken")));
        QVERIFY(!json.contains(QStringLiteral("enc-secret")));
        QVERIFY(!json.contains(QStringLiteral("token-222")));

        // Không thay đổi gì thì không có "changes" rỗng trong log.
        QVERIFY(SettingsController::auditChanges(before, before).isEmpty());
    }

    void viewerCannotChangeDraftOrReadCredentials()
    {
        UserAccount viewer = makeUser(QStringLiteral("viewer"), UserRole::Viewer);
        QVERIFY(insertUser(viewer) > 0);
        {
            ScopedDbConnection db;
            AppConfigDao dao(db);
            AppConfig config = dao.load();
            config.serverActive = true;
            config.restApiEnabled = true;
            config.restApiToken = QStringLiteral("device-token-secret");
            config.ftpPassword = QStringLiteral("encrypted-ftp-secret");
            QVERIFY(dao.save(config));
        }
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("viewer"), QStringLiteral("test-password")));
        SettingsController settings(nullptr);
        settings.loadConfig();
        const AppConfig before = settings.config();
        settings.setStationName(QStringLiteral("not allowed"));
        settings.setServerActive(false);
        settings.setFtpPassword(QStringLiteral("not allowed"));
        settings.setRestApiEnabled(false);
        QCOMPARE(settings.config().stationName, before.stationName);
        QCOMPARE(settings.config().serverActive, before.serverActive);
        QCOMPARE(settings.config().ftpPassword, before.ftpPassword);
        QCOMPARE(settings.config().restApiEnabled, before.restApiEnabled);
        QVERIFY(settings.restApiToken().isEmpty());
        QVERIFY(settings.ftpPassword().isEmpty());
        QVERIFY(!settings.provisionQrAvailable());
        QVERIFY(settings.get_provision_qr_base64().isEmpty());
    }

    void settingsRevisionDoesNotMoveBackwards()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));
        SettingsController settings(nullptr);
        settings.loadConfig();
        int revision = 0;
        {
            ScopedDbConnection db;
            revision = AppConfigDao(db).bumpRevision();
            QVERIFY(revision >= 0);
        }
        const QString theme = settings.theme() == QStringLiteral("dark")
            ? QStringLiteral("light") : QStringLiteral("dark");
        QVERIFY(settings.saveTheme(theme));
        {
            ScopedDbConnection db;
            QCOMPARE(AppConfigDao(db).load().configRevision, revision + 1);
        }
        QCOMPARE(settings.configRevision(), revision + 1);
    }

    void tokenRegenerationRollsBackOnStorageFailure()
    {
        UserAccount admin = makeUser(QStringLiteral("admin"), UserRole::Admin);
        QVERIFY(insertUser(admin) > 0);
        {
            ScopedDbConnection db;
            AppConfigDao dao(db);
            AppConfig cfg = dao.load();
            cfg.restApiToken = QStringLiteral("original-token");
            QVERIFY(dao.save(cfg));
        }
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin"), QStringLiteral("test-password")));
        SettingsController settings(nullptr);
        settings.loadConfig();
        const int revision = settings.configRevision();
        {
            ScopedDbConnection db;
            QSqlQuery query(db);
            QVERIFY(query.exec(QStringLiteral("CREATE TRIGGER reject_token BEFORE UPDATE OF rest_api_token "
                                              "ON app_config BEGIN SELECT RAISE(ABORT, 'test'); END")));
        }
        settings.regenerateRestToken();
        QCOMPARE(settings.restApiToken(), QStringLiteral("original-token"));
        QCOMPARE(settings.configRevision(), revision);
        {
            ScopedDbConnection db;
            QCOMPARE(AppConfigDao(db).load().restApiToken, QStringLiteral("original-token"));
            QSqlQuery query(db);
            QVERIFY(query.exec(QStringLiteral("DROP TRIGGER reject_token")));
        }
        QVERIFY(auditEntries(QStringLiteral("settings.rest_token.regenerate")).isEmpty());
        settings.regenerateRestToken();
        QVERIFY(settings.restApiToken() != QStringLiteral("original-token"));
        QCOMPARE(settings.configRevision(), revision + 1);
        QCOMPARE(auditEntries(QStringLiteral("settings.rest_token.regenerate")).size(), 1);
    }

    void systemOnlyOperationsAreNotQmlSlots()
    {
        QCOMPARE(SettingsController::staticMetaObject.indexOfMethod("syncSystemTime()"), -1);
        QCOMPARE(MonitorController::staticMetaObject.indexOfMethod("stopPolling()"), -1);
        QCOMPARE(MonitorController::staticMetaObject.indexOfMethod("writeDo(int,bool)"), -1);
        QCOMPARE(ReportController::staticMetaObject.indexOfMethod("applyServerConfig()"), -1);
        QCOMPARE(RestApiService::staticMetaObject.indexOfMethod("stop()"), -1);
        QCOMPARE(ModbusTcpServerService::staticMetaObject.indexOfMethod("stop()"), -1);
    }

private:
    QTemporaryDir m_tempDir;
    QString m_dbPath;
};

QTEST_GUILESS_MAIN(AuditTest)

#include "audit_test.moc"
