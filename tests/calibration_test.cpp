#include "core/AuthService.h"
#include "core/CalibrationController.h"
#include "core/SensorListModel.h"
#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/AuditLogDao.h"
#include "data/repositories/CalibrationDao.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/UserAccountDao.h"
#include "utils/calc/CalibrationMath.h"
#include "utils/modbus/Formula.h"
#include "utils/security/PasswordHasher.h"

#include <QFile>
#include <QSignalSpy>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>
#include <cmath>
#include <limits>

namespace {

void closeConnections()
{
    const QStringList names = QSqlDatabase::connectionNames();
    for (const QString &name : names) {
        QSqlDatabase db = QSqlDatabase::database(name, false);
        db.close();
    }
    for (const QString &name : names)
        QSqlDatabase::removeDatabase(name);
}

bool near(double actual, double expected, double tolerance = 1e-12)
{
    return std::abs(actual - expected) <= tolerance * qMax(1.0, std::abs(expected));
}

QVariantList points()
{
    return {
        QVariantMap{{QStringLiteral("raw"), QStringLiteral("4000")},
                    {QStringLiteral("reference"), QStringLiteral("4")}},
        QVariantMap{{QStringLiteral("raw"), 12000},
                    {QStringLiteral("reference"), QStringLiteral("12,0")}},
        QVariantMap{{QStringLiteral("raw"), 20000.0},
                    {QStringLiteral("reference"), 20.0}},
    };
}

bool login(AuthService &auth, const QString &username)
{
    auth.login(username, QStringLiteral("testing123"));
    return QTest::qWaitFor([&auth]() { return !auth.busy(); }, 60000)
        && auth.authenticated();
}

struct Snapshot {
    QString coefficient;
    int revision = -1;
    int sessions = -1;
    int points = -1;
    QList<AuditLogEntry> audit;
};

Snapshot snapshot(int sensorId)
{
    ScopedDbConnection db;
    SensorDao sensors(db);
    AppConfigDao config(db);
    CalibrationDao calibrations(db);
    AuditLogDao audit(db);
    Snapshot state;
    state.coefficient = sensors.loadById(sensorId).coefficient;
    state.revision = config.load().configRevision;
    state.sessions = calibrations.countForSensor(sensorId);
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT COUNT(*) FROM calibration_point p "
                                 "JOIN calibration_session s ON s.id=p.session_id "
                                 "WHERE s.sensor_id=:id"));
    query.bindValue(QStringLiteral(":id"), sensorId);
    if (query.exec() && query.next())
        state.points = query.value(0).toInt();
    AuditLogQuery filter;
    filter.actionPrefix = QStringLiteral("calibration.apply");
    state.audit = audit.query(filter);
    return state;
}

} // namespace

// Hồi quy và luồng áp dụng thật: kiểm tra runtime Formula, RBAC, rollback,
// audit không lộ JSON/ghi chú tự do và cascade khi xóa cảm biến.
class CalibrationTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_tempDir.isValid());
        m_path = m_tempDir.path() + QStringLiteral("/calibration.db");
        m_hash = PasswordHasher::hash(QStringLiteral("testing123"));
        QVERIFY(!m_hash.isEmpty());
    }

    void cleanupTestCase() { closeConnections(); }

    void init()
    {
        AuthService::setInstance(nullptr);
        SensorListModel::setInstance(nullptr);
        closeConnections();
        QFile::remove(m_path);
        QVERIFY(Database::init(m_path));
        ScopedDbConnection db;
        AppConfigDao config(db);
        QVERIFY(config.load().id > 0);
    }

    void cleanup()
    {
        AuthService::setInstance(nullptr);
        SensorListModel::setInstance(nullptr);
        closeConnections();
    }

    void fitTwoPointsAtNonzeroOrigin()
    {
        const auto fit = CalibrationMath::fit({{4000.0, 4.0}, {20000.0, 20.0}});
        QVERIFY2(fit.ok, qPrintable(fit.error));
        QVERIFY(near(fit.a, 0.001));
        QVERIFY(near(fit.b, 0.0));
        QCOMPARE(fit.residuals.size(), 2);
        QVERIFY(near(fit.residuals[0], 0.0));
        QVERIFY(near(fit.residuals[1], 0.0));
        QVERIFY(fit.r2.has_value());
        QVERIFY(near(*fit.r2, 1.0));
        const QString json = CalibrationMath::coefficientJson(fit.a, fit.b);
        QVERIFY(near(Formula::applyFormula(4000.0, json), 4.0));
        QVERIFY(near(Formula::applyFormula(20000.0, json), 20.0));

        const auto shifted = CalibrationMath::fit({{100.0, 3.0}, {200.0, 7.0}});
        QVERIFY(shifted.ok);
        QVERIFY(near(shifted.a, 0.04));
        QVERIFY(near(shifted.b, -1.0));
    }

    void fitManyPointsAndResiduals()
    {
        const auto fit = CalibrationMath::fit({{0, 1}, {1, 3}, {2, 6}});
        QVERIFY(fit.ok);
        QVERIFY(near(fit.a, 2.5));
        QVERIFY(near(fit.b, 5.0 / 6.0));
        QVERIFY(fit.r2.has_value());
        QVERIFY(near(*fit.r2, 75.0 / 76.0));
        QCOMPARE(fit.residuals.size(), 3);
        QVERIFY(near(fit.residuals[0], 1.0 / 6.0));
        QVERIFY(near(fit.residuals[1], -1.0 / 3.0));
        QVERIFY(near(fit.residuals[2], 1.0 / 6.0));
        QVERIFY(fit.maxResidual.has_value());
        QVERIFY(near(*fit.maxResidual, 1.0 / 3.0));

        const auto constant = CalibrationMath::fit({{5, 7}, {10, 7}, {20, 7}});
        QVERIFY(constant.ok);
        QVERIFY(!constant.r2.has_value());
        QVERIFY(near(constant.a, 0));
        QVERIFY(near(constant.b, 7));
    }

    void invalidAndSmallValues()
    {
        QVERIFY(!CalibrationMath::fit({}).ok);
        QVERIFY(!CalibrationMath::fit({{1, 2}}).ok);
        QVERIFY(!CalibrationMath::fit({{1, 2}, {1, 3}}).ok);
        QVERIFY(!CalibrationMath::fit({{1, 2}, {2, std::numeric_limits<double>::infinity()}}).ok);
        QVERIFY(!CalibrationMath::fit({{std::numeric_limits<double>::quiet_NaN(), 2}, {2, 3}}).ok);
        // Giá trị rất nhỏ nhưng tách biệt vẫn là dữ liệu hợp lệ.
        const auto small = CalibrationMath::fit({{1e-15, 1}, {2e-15, 2}});
        QVERIFY(small.ok);
        QVERIFY(near(small.a, 1e15));
        QVERIFY(!CalibrationMath::fit({{1e-100, -1e308}, {2e-100, 1e308}}).ok);
    }

    void coefficientCodec()
    {
        const double originalA = 0.12345678901234566;
        const double originalB = -9876.543210987654;
        double a = 0, b = 0;
        QVERIFY(CalibrationMath::parseCoefficient(
            CalibrationMath::coefficientJson(originalA, originalB), &a, &b));
        QCOMPARE(a, originalA);
        QCOMPARE(b, originalB);
        QVERIFY(!CalibrationMath::parseCoefficient(QStringLiteral("{\"a\":\"2\",\"b\":3}"), &a, &b));
        QCOMPARE(a, originalA);
        QCOMPARE(b, originalB);
        QVERIFY(!CalibrationMath::parseCoefficient(QStringLiteral("{\"coeffs\":[1,2]}"), &a, &b));
    }

    void operatorAppliesAtomically()
    {
        QVERIFY(addUser(QStringLiteral("operator"), UserRole::Operator));
        const QString original = QStringLiteral("{\"secret\":\"do-not-copy\",\"a\":4}");
        const int id = addSensor(QStringLiteral("ANALOG"), original);
        QVERIFY(id > 0);
        const Snapshot before = snapshot(id);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("operator")));
        CalibrationController controller;
        QVERIFY(!controller.current(id).value(QStringLiteral("hasCoefficient")).toBool());
        const QVariantMap result = controller.apply(id, points(), QStringLiteral("do-not-copy-note"));
        QVERIFY2(result.value(QStringLiteral("ok")).toBool(),
                 qPrintable(result.value(QStringLiteral("error")).toString()));
        const Snapshot after = snapshot(id);
        QCOMPARE(after.sessions, 1);
        QCOMPARE(after.points, 3);
        QCOMPARE(after.revision, before.revision + 1);
        QVERIFY(near(Formula::applyFormula(4000, after.coefficient), 4));
        QCOMPARE(after.audit.size(), 1);
        QCOMPARE(after.audit.first().actorUsername, QStringLiteral("operator"));
        QVERIFY(!after.audit.first().detailJson.contains(QStringLiteral("do-not-copy")));
        QVERIFY(!after.audit.first().detailJson.contains(QStringLiteral("do-not-copy-note")));

        const auto history = controller.history(id);
        QCOMPARE(history.size(), 1);
        QCOMPARE(controller.sessionPoints(result.value(QStringLiteral("sessionId")).toInt()).size(), 3);
        QCOMPARE(history.first().toMap().value(QStringLiteral("createdByUsername")).toString(),
                 QStringLiteral("operator"));
    }

    void deniedViewerAndDigitalSensor()
    {
        QVERIFY(addUser(QStringLiteral("viewer"), UserRole::Viewer));
        QVERIFY(addUser(QStringLiteral("operator"), UserRole::Operator));
        const int analog = addSensor(QStringLiteral("ANALOG"), QStringLiteral("{}"));
        const int digital = addSensor(QStringLiteral("DI"), QStringLiteral("{}"));
        QVERIFY(analog > 0 && digital > 0);

        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("viewer")));
        CalibrationController controller;
        const Snapshot before = snapshot(analog);
        QVERIFY(!controller.apply(analog, points(), {}).value(QStringLiteral("ok")).toBool());
        Snapshot after = snapshot(analog);
        QCOMPARE(after.coefficient, before.coefficient);
        QCOMPARE(after.revision, before.revision);
        QCOMPARE(after.sessions, 0);
        QCOMPARE(after.audit.size(), 1);
        QCOMPARE(after.audit.first().result, AuditResult::Denied);

        auth.logout();
        QVERIFY(login(auth, QStringLiteral("operator")));
        QVERIFY(!controller.apply(digital, points(), {}).value(QStringLiteral("ok")).toBool());
        after = snapshot(digital);
        QCOMPARE(after.sessions, 0);
        QCOMPARE(after.points, 0);
        QCOMPARE(after.revision, before.revision);
    }

    void auditAndRevisionFailuresRollBack()
    {
        QVERIFY(addUser(QStringLiteral("operator"), UserRole::Operator));
        const int id = addSensor(QStringLiteral("ANALOG"), QStringLiteral("{}"));
        QVERIFY(id > 0);
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("operator")));
        CalibrationController controller;
        const Snapshot before = snapshot(id);

        QVERIFY(exec(QStringLiteral("CREATE TRIGGER reject_calibration_audit BEFORE INSERT ON audit_log "
                                    "WHEN NEW.action='calibration.apply' BEGIN SELECT RAISE(ABORT, 'test'); END")));
        QVERIFY(!controller.apply(id, points(), {}).value(QStringLiteral("ok")).toBool());
        Snapshot after = snapshot(id);
        QCOMPARE(after.coefficient, before.coefficient);
        QCOMPARE(after.revision, before.revision);
        QCOMPARE(after.sessions, 0);
        QCOMPARE(after.points, 0);
        QVERIFY(after.audit.isEmpty());
        QVERIFY(exec(QStringLiteral("DROP TRIGGER reject_calibration_audit")));

        QVERIFY(exec(QStringLiteral("CREATE TRIGGER reject_revision BEFORE UPDATE ON app_config "
                                    "BEGIN SELECT RAISE(ABORT, 'test'); END")));
        QVERIFY(!controller.apply(id, points(), {}).value(QStringLiteral("ok")).toBool());
        after = snapshot(id);
        QCOMPARE(after.coefficient, before.coefficient);
        QCOMPARE(after.revision, before.revision);
        QCOMPARE(after.sessions, 0);
        QCOMPARE(after.points, 0);
        QVERIFY(after.audit.isEmpty());
    }

    void sensorDeletionRollsBackAndCascades()
    {
        QVERIFY(addUser(QStringLiteral("admin"), UserRole::Admin));
        const int id = addSensor(QStringLiteral("ANALOG"), QStringLiteral("{}"));
        QVERIFY(id > 0);
        AuthService auth;
        AuthService::setInstance(&auth);
        QVERIFY(login(auth, QStringLiteral("admin")));
        CalibrationController controller;
        QVERIFY(controller.apply(id, points(), {}).value(QStringLiteral("ok")).toBool());
        const Snapshot before = snapshot(id);
        SensorListModel model(nullptr);
        QVERIFY(exec(QStringLiteral("CREATE TRIGGER reject_delete_audit BEFORE INSERT ON audit_log "
                                    "WHEN NEW.action='sensor.delete' BEGIN SELECT RAISE(ABORT, 'test'); END")));
        QVERIFY(!model.removeSensor(id));
        const Snapshot after = snapshot(id);
        QCOMPARE(after.coefficient, before.coefficient);
        QCOMPARE(after.sessions, 1);
        QCOMPARE(after.points, 3);
        QCOMPARE(after.revision, before.revision);
        QVERIFY(exec(QStringLiteral("DROP TRIGGER reject_delete_audit")));
        QVERIFY(model.removeSensor(id));
        const Snapshot deleted = snapshot(id);
        QCOMPARE(deleted.sessions, 0);
        QCOMPARE(deleted.points, 0);
        QCOMPARE(deleted.revision, before.revision + 1);
    }

private:
    bool addUser(const QString &name, UserRole role)
    {
        ScopedDbConnection db;
        UserAccountDao dao(db);
        UserAccount user;
        user.username = name;
        user.displayName = name;
        user.role = role;
        user.passwordHash = m_hash;
        return dao.insert(user);
    }

    int addSensor(const QString &type, const QString &coefficient)
    {
        ScopedDbConnection db;
        QSqlQuery q(db);
        q.prepare(QStringLiteral("INSERT INTO sensor (sensor_type, name, slave_id, register_address, coefficient) "
                                 "VALUES (:type, 'test', 1, 0, :coefficient)"));
        q.bindValue(QStringLiteral(":type"), type);
        q.bindValue(QStringLiteral(":coefficient"), coefficient);
        return q.exec() ? q.lastInsertId().toInt() : 0;
    }

    bool exec(const QString &statement)
    {
        ScopedDbConnection db;
        QSqlQuery q(db);
        return q.exec(statement);
    }

    QTemporaryDir m_tempDir;
    QString m_path;
    QString m_hash;
};

QTEST_MAIN(CalibrationTest)
#include "calibration_test.moc"
