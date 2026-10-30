#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/AuditLogDao.h"
#include "network/rest/RestConfigUpdater.h"

#include <QFile>
#include <QJsonArray>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

namespace {
void closeConnections()
{
    const QStringList names = QSqlDatabase::connectionNames();
    for (const auto &name : names) {
        QSqlDatabase db = QSqlDatabase::database(name, false);
        db.close();
    }
    for (const auto &name : names)
        QSqlDatabase::removeDatabase(name);
}
}

// REST v1 vẫn dùng credential thiết bị, chỉ ghi app-config. Audit không chứa
// token/body tùy ý và phải rollback cấu hình khi không ghi được dấu vết.
class RestConfigTest : public QObject {
    Q_OBJECT
private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_path = m_dir.path() + QStringLiteral("/rest-config.db");
    }
    void init()
    {
        closeConnections();
        QFile::remove(m_path);
        QVERIFY(Database::init(m_path));
        ScopedDbConnection db;
        AppConfigDao dao(db);
        AppConfig config = dao.load();
        QVERIFY(config.id > 0);
        config.restApiToken = QStringLiteral("original-token-secret");
        config.ftpPassword = QStringLiteral("encrypted-ftp-secret");
        QVERIFY(dao.save(config));
    }
    void cleanup() { closeConnections(); }

    void successfulWriteIsDeviceAudited()
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        const AppConfig before = dao.load();
        QSqlQuery insert(db);
        QVERIFY(insert.exec(QStringLiteral("INSERT INTO sensor (name,slave_id,register_address) VALUES ('original',1,0)")));

        QJsonObject body{{QStringLiteral("station_name"), QStringLiteral("Remote station")},
                         {QStringLiteral("poll_interval"), 10},
                         {QStringLiteral("serial_port"), QStringLiteral("/dev/ttyUSB0")},
                         {QStringLiteral("rest_api_token"), QStringLiteral("forbidden-new-secret")},
                         {QStringLiteral("sensors"), QJsonArray{QJsonObject{{QStringLiteral("name"), QStringLiteral("changed")}}}}};
        const auto result = RestConfigUpdater::apply(db.get(), body, QStringLiteral("192.0.2.4"));
        QCOMPARE(result.status, RestConfigUpdater::Status::Ok);
        const AppConfig after = dao.load();
        QCOMPARE(result.revision, before.configRevision + 1);
        QCOMPARE(after.configRevision, result.revision);
        QCOMPARE(after.stationName, QStringLiteral("Remote station"));
        QCOMPARE(after.pollInterval, 10);
        QCOMPARE(after.restApiToken, before.restApiToken);
        QCOMPARE(after.ftpPassword, before.ftpPassword);
        QSqlQuery sensor(db);
        QVERIFY(sensor.exec(QStringLiteral("SELECT name FROM sensor LIMIT 1")));
        QVERIFY(sensor.next());
        QCOMPARE(sensor.value(0).toString(), QStringLiteral("original"));

        AuditLogQuery filter;
        filter.actionPrefix = QStringLiteral("settings.remote_save");
        const auto entries = AuditLogDao(db).query(filter);
        QCOMPARE(entries.size(), 1);
        QCOMPARE(entries.first().actorKind, AuditActorKind::RemoteDevice);
        QCOMPARE(entries.first().actorUsername, QStringLiteral("192.0.2.4"));
        QVERIFY(entries.first().detailJson.contains(QStringLiteral("Remote station")));
        QVERIFY(!entries.first().detailJson.contains(QStringLiteral("secret")));
        QVERIFY(!entries.first().detailJson.contains(QStringLiteral("sensors")));
    }

    void badInputDoesNotWrite()
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        const AppConfig before = dao.load();
        const auto result = RestConfigUpdater::apply(
            db.get(), {{QStringLiteral("poll_interval"), 0}}, QStringLiteral("192.0.2.4"));
        QCOMPARE(result.status, RestConfigUpdater::Status::BadRequest);
        QCOMPARE(dao.load().configRevision, before.configRevision);
        QCOMPARE(AuditLogDao(db).count({}), 0);
    }

    void auditFailureRollsBack()
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        const AppConfig before = dao.load();
        QSqlQuery trigger(db);
        QVERIFY(trigger.exec(QStringLiteral("CREATE TRIGGER fail_remote_audit BEFORE INSERT ON audit_log "
                                            "BEGIN SELECT RAISE(ABORT,'test'); END")));
        const auto result = RestConfigUpdater::apply(
            db.get(), {{QStringLiteral("station_name"), QStringLiteral("must roll back")}},
            QStringLiteral("192.0.2.4"));
        QCOMPARE(result.status, RestConfigUpdater::Status::StorageError);
        const AppConfig after = dao.load();
        QCOMPARE(after.stationName, before.stationName);
        QCOMPARE(after.configRevision, before.configRevision);
        QCOMPARE(AuditLogDao(db).count({}), 0);
    }

private:
    QTemporaryDir m_dir;
    QString m_path;
};

QTEST_GUILESS_MAIN(RestConfigTest)
#include "rest_config_test.moc"
