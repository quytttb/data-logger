#include "data/db/Database.h"
#include "data/repositories/AuditLogDao.h"
#include "data/repositories/CalibrationDao.h"

#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>
#include <cmath>
#include <limits>

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

} // namespace

// Slice 0: lưu phiên hiệu chuẩn nhiều điểm, transaction chung với cập nhật
// coefficient/audit, và cascade khi xóa cảm biến/phiên.
class CalibrationDaoTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tempDir.isValid());
        m_dbPath = m_tempDir.path() + QStringLiteral("/calibration-test.db");
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

    void saveSessionWithPointsAndHistory()
    {
        ScopedDbConnection db;
        const int sensorId = insertSensor(db);
        const int userId = insertUser(db);
        QVERIFY(sensorId > 0);
        QVERIFY(userId > 0);

        QSqlQuery updateCoeff(db);
        updateCoeff.prepare(QStringLiteral("UPDATE sensor SET coefficient = :coeff WHERE id = :id"));
        updateCoeff.bindValue(QStringLiteral(":coeff"), QStringLiteral(R"({"a":2.5,"b":-1.0})"));
        updateCoeff.bindValue(QStringLiteral(":id"), sensorId);
        QVERIFY(updateCoeff.exec());

        CalibrationSession session;
        session.sensorId = sensorId;
        session.a = 2.5;
        session.b = -1.0;
        session.r2 = 0.9998;
        session.maxResidual = 0.02;
        session.note = QStringLiteral("Hiệu chuẩn định kỳ");
        session.createdBy = userId;
        session.createdByUsername = QStringLiteral("operator1");

        const QList<CalibrationPoint> points {
            {0, 4.0, 9.0, QStringLiteral("điểm 1")},
            {0, 12.0, 29.0, QStringLiteral("điểm 2")},
            {0, 20.0, 49.0, QStringLiteral("điểm 3")},
        };

        QVERIFY(db.get().transaction());

        AuditLogEntry audit;
        audit.actorKind = AuditActorKind::Local;
        audit.actorUserId = userId;
        audit.actorUsername = QStringLiteral("operator1");
        audit.actorDisplayName = QStringLiteral("Người vận hành");
        audit.action = QStringLiteral("calibration.apply");
        audit.entity = QStringLiteral("sensor");
        audit.entityId = QString::number(sensorId);
        audit.detailJson = QStringLiteral(R"({"points":3,"a":2.5,"b":-1.0})");
        AuditLogDao auditDao(db);
        QVERIFY(auditDao.append(audit));

        CalibrationDao dao(db);
        QVERIFY(dao.saveSession(session, points));
        QVERIFY(session.id > 0);
        QCOMPARE(session.pointCount, 3);
        QCOMPARE(session.points.size(), 3);

        QVERIFY(db.get().commit());

        const auto latest = dao.latestForSensor(sensorId);
        QVERIFY(latest.has_value());
        QCOMPARE(latest->id, session.id);
        QCOMPARE(latest->pointCount, 3);
        QCOMPARE(latest->a, 2.5);
        QCOMPARE(latest->b, -1.0);
        QVERIFY(latest->r2.has_value());
        QCOMPARE(*latest->r2, 0.9998);
        QCOMPARE(latest->createdBy, userId);
        QCOMPARE(latest->createdByUsername, QStringLiteral("operator1"));
        QCOMPARE(latest->note, QStringLiteral("Hiệu chuẩn định kỳ"));
        QCOMPARE(latest->points.size(), 3);
        QCOMPARE(latest->points.at(0).rawValue, 4.0);
        QCOMPARE(latest->points.at(2).referenceValue, 49.0);
        QVERIFY(latest->points.at(0).id > 0);

        QCOMPARE(dao.countForSensor(sensorId), 1);
        QCOMPARE(dao.recentSessions(sensorId, 1).size(), 1);
        QCOMPARE(auditDao.count(AuditLogQuery {}), 1);

        QSqlQuery checkCoeff(db);
        checkCoeff.prepare(QStringLiteral("SELECT coefficient FROM sensor WHERE id = :id"));
        checkCoeff.bindValue(QStringLiteral(":id"), sensorId);
        QVERIFY(checkCoeff.exec());
        QVERIFY(checkCoeff.next());
        QCOMPARE(checkCoeff.value(0).toString(), QStringLiteral(R"({"a":2.5,"b":-1.0})"));
    }

    void rejectsInvalidSessions()
    {
        ScopedDbConnection db;
        const int sensorId = insertSensor(db);
        QVERIFY(sensorId > 0);
        CalibrationDao dao(db);

        CalibrationSession session;
        session.sensorId = sensorId;
        session.a = 1.0;
        session.b = 0.0;

        QVERIFY(!dao.saveSession(session, {{0, 1.0, 1.0, {}}}));

        QList<CalibrationPoint> points {
            {0, 1.0, 1.0, {}},
            {0, 2.0, 2.0, {}},
        };
        points[1].rawValue = std::numeric_limits<double>::quiet_NaN();
        QVERIFY(!dao.saveSession(session, points));

        points[1].rawValue = 2.0;
        session.a = std::numeric_limits<double>::infinity();
        QVERIFY(!dao.saveSession(session, points));

        session.a = 1.0;
        session.sensorId = 0;
        QVERIFY(!dao.saveSession(session, points));

        QCOMPARE(dao.countForSensor(sensorId), 0);
    }

    void deleteSessionCascadesPoints()
    {
        ScopedDbConnection db;
        const int sensorId = insertSensor(db);
        QVERIFY(sensorId > 0);
        CalibrationDao dao(db);

        CalibrationSession session;
        session.sensorId = sensorId;
        session.a = 1.0;
        session.b = 0.0;
        QVERIFY(dao.saveSession(session, {{0, 1.0, 1.0, {}}, {0, 2.0, 2.0, {}}}));
        QVERIFY(session.id > 0);

        QCOMPARE(dao.pointsForSession(session.id).size(), 2);
        QVERIFY(dao.removeSession(session.id));
        QCOMPARE(dao.pointsForSession(session.id).size(), 0);
        QCOMPARE(dao.countForSensor(sensorId), 0);
    }

    void deleteSensorCascadesSessionsAndPoints()
    {
        ScopedDbConnection db;
        const int sensorId = insertSensor(db);
        QVERIFY(sensorId > 0);
        CalibrationDao dao(db);

        CalibrationSession session;
        session.sensorId = sensorId;
        session.a = 1.0;
        session.b = 0.0;
        QVERIFY(dao.saveSession(session, {{0, 1.0, 1.0, {}}, {0, 2.0, 2.0, {}}}));

        QSqlQuery remove(db);
        remove.prepare(QStringLiteral("DELETE FROM sensor WHERE id = :id"));
        remove.bindValue(QStringLiteral(":id"), sensorId);
        QVERIFY(remove.exec());

        QCOMPARE(dao.countForSensor(sensorId), 0);
        QCOMPARE(dao.pointsForSession(session.id).size(), 0);
    }

    void rollbackKeepsOldCoefficient()
    {
        ScopedDbConnection db;
        const int sensorId = insertSensor(db);
        QVERIFY(sensorId > 0);
        CalibrationDao dao(db);

        QVERIFY(db.get().transaction());

        QSqlQuery updateCoeff(db);
        updateCoeff.prepare(QStringLiteral("UPDATE sensor SET coefficient = :coeff WHERE id = :id"));
        updateCoeff.bindValue(QStringLiteral(":coeff"), QStringLiteral(R"({"a":9.0,"b":9.0})"));
        updateCoeff.bindValue(QStringLiteral(":id"), sensorId);
        QVERIFY(updateCoeff.exec());

        CalibrationSession session;
        session.sensorId = sensorId;
        session.a = 9.0;
        session.b = 9.0;
        QVERIFY(dao.saveSession(session, {{0, 1.0, 1.0, {}}, {0, 2.0, 2.0, {}}}));

        QVERIFY(db.get().rollback());

        QSqlQuery coeff(db);
        coeff.prepare(QStringLiteral("SELECT coefficient FROM sensor WHERE id = :id"));
        coeff.bindValue(QStringLiteral(":id"), sensorId);
        QVERIFY(coeff.exec());
        QVERIFY(coeff.next());
        QCOMPARE(coeff.value(0).toString(), QStringLiteral("{}"));
        QCOMPARE(dao.countForSensor(sensorId), 0);
    }

private:
    static int insertSensor(ScopedDbConnection &db)
    {
        QSqlQuery query(db);
        query.prepare(QStringLiteral(
            "INSERT INTO sensor (name, slave_id, register_address) VALUES ('CEMS', 1, 0)"));
        if (!query.exec())
            return 0;
        return query.lastInsertId().toInt();
    }

    static int insertUser(ScopedDbConnection &db)
    {
        QSqlQuery query(db);
        query.prepare(QStringLiteral(
            "INSERT INTO user_account (username, display_name, role, password_hash) "
            "VALUES ('operator1', 'Người vận hành', 'operator', 'pbkdf2-sha256$1$c2FsdA==$aGFzaA==')"));
        if (!query.exec())
            return 0;
        return query.lastInsertId().toInt();
    }

    QTemporaryDir m_tempDir;
    QString m_dbPath;
};

QTEST_MAIN(CalibrationDaoTest)
#include "calibration_dao_test.moc"
