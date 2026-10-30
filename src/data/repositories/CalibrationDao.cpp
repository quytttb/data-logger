#include "CalibrationDao.h"
#include "data/db/TimeCodec.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QtDebug>
#include <cmath>

namespace {

QString textOrEmpty(const QString &value)
{
    return value.isNull() ? QStringLiteral("") : value;
}

} // namespace

CalibrationDao::CalibrationDao(QSqlDatabase db) : m_db(std::move(db)) {}

CalibrationSession CalibrationDao::rowToSession(const QSqlRecord &record)
{
    CalibrationSession session;
    session.id                = record.value(QStringLiteral("id")).toInt();
    session.sensorId          = record.value(QStringLiteral("sensor_id")).toInt();
    session.method            = record.value(QStringLiteral("method")).toString();
    session.pointCount        = record.value(QStringLiteral("point_count")).toInt();
    session.a                 = record.value(QStringLiteral("a")).toDouble();
    session.b                 = record.value(QStringLiteral("b")).toDouble();
    const QVariant r2         = record.value(QStringLiteral("r2"));
    const QVariant residual   = record.value(QStringLiteral("max_residual"));
    if (!r2.isNull())
        session.r2 = r2.toDouble();
    if (!residual.isNull())
        session.maxResidual = residual.toDouble();
    session.note              = record.value(QStringLiteral("note")).toString();
    session.createdBy         = record.value(QStringLiteral("created_by")).toInt();
    session.createdByUsername = record.value(QStringLiteral("created_by_username")).toString();
    session.createdAt         = TimeCodec::fromDb(record.value(QStringLiteral("created_at")));
    return session;
}

bool CalibrationDao::saveSession(CalibrationSession &session,
                                 const QList<CalibrationPoint> &points)
{
    if (session.sensorId <= 0) {
        qWarning() << "CalibrationDao::saveSession: sensor_id không hợp lệ";
        return false;
    }
    if (points.size() < 2) {
        qWarning() << "CalibrationDao::saveSession: cần ít nhất 2 điểm";
        return false;
    }
    if (!std::isfinite(session.a) || !std::isfinite(session.b)) {
        qWarning() << "CalibrationDao::saveSession: hệ số a/b không hữu hạn";
        return false;
    }
    for (const CalibrationPoint &point : points) {
        if (!std::isfinite(point.rawValue) || !std::isfinite(point.referenceValue)) {
            qWarning() << "CalibrationDao::saveSession: điểm không hữu hạn";
            return false;
        }
    }

    if (!session.createdAt.isValid())
        session.createdAt = QDateTime::currentDateTimeUtc();
    session.pointCount = points.size();
    session.method = session.method.trimmed().isEmpty()
                         ? QStringLiteral("linear") : session.method.trimmed();

    if (!session.r2.has_value() || !std::isfinite(*session.r2))
        session.r2 = std::nullopt;
    if (!session.maxResidual.has_value() || !std::isfinite(*session.maxResidual))
        session.maxResidual = std::nullopt;

    QSqlQuery insertSession(m_db);
    insertSession.prepare(R"(
        INSERT INTO calibration_session
            (sensor_id, method, point_count, a, b, r2, max_residual, note,
             created_by, created_by_username, created_at)
        VALUES
            (:sensor_id, :method, :point_count, :a, :b, :r2, :max_residual, :note,
             :created_by, :created_by_username, :created_at))");
    insertSession.bindValue(QStringLiteral(":sensor_id"), session.sensorId);
    insertSession.bindValue(QStringLiteral(":method"), session.method);
    insertSession.bindValue(QStringLiteral(":point_count"), session.pointCount);
    insertSession.bindValue(QStringLiteral(":a"), session.a);
    insertSession.bindValue(QStringLiteral(":b"), session.b);
    insertSession.bindValue(QStringLiteral(":r2"), session.r2.has_value()
                                ? QVariant(*session.r2) : QVariant());
    insertSession.bindValue(QStringLiteral(":max_residual"), session.maxResidual.has_value()
                                ? QVariant(*session.maxResidual) : QVariant());
    insertSession.bindValue(QStringLiteral(":note"), textOrEmpty(session.note));
    insertSession.bindValue(QStringLiteral(":created_by"),
                            session.createdBy > 0 ? QVariant(session.createdBy) : QVariant());
    insertSession.bindValue(QStringLiteral(":created_by_username"), textOrEmpty(session.createdByUsername));
    insertSession.bindValue(QStringLiteral(":created_at"), TimeCodec::toDb(session.createdAt));

    if (!insertSession.exec()) {
        qWarning() << "CalibrationDao::saveSession (session):" << insertSession.lastError().text();
        return false;
    }

    session.id = insertSession.lastInsertId().toInt();
    if (session.id <= 0)
        return false;

    QSqlQuery insertPoint(m_db);
    insertPoint.prepare(R"(
        INSERT INTO calibration_point (session_id, raw_value, reference_value, note)
        VALUES (:session_id, :raw_value, :reference_value, :note))");

    session.points = points;
    for (int i = 0; i < session.points.size(); ++i) {
        CalibrationPoint &point = session.points[i];
        insertPoint.bindValue(QStringLiteral(":session_id"), session.id);
        insertPoint.bindValue(QStringLiteral(":raw_value"), point.rawValue);
        insertPoint.bindValue(QStringLiteral(":reference_value"), point.referenceValue);
        insertPoint.bindValue(QStringLiteral(":note"), textOrEmpty(point.note));

        if (!insertPoint.exec()) {
            qWarning() << "CalibrationDao::saveSession (point):" << insertPoint.lastError().text();
            return false;
        }
        point.id = insertPoint.lastInsertId().toInt();
    }

    return true;
}

QList<CalibrationSession> CalibrationDao::recentSessions(int sensorId, int limit) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT * FROM calibration_session WHERE sensor_id = :sensor_id "
        "ORDER BY id DESC LIMIT :limit"));
    query.bindValue(QStringLiteral(":sensor_id"), sensorId);
    query.bindValue(QStringLiteral(":limit"), qBound(1, limit, 1000));

    if (!query.exec()) {
        qWarning() << "CalibrationDao::recentSessions:" << query.lastError().text();
        return {};
    }

    QList<CalibrationSession> sessions;
    while (query.next())
        sessions.append(rowToSession(query.record()));
    return sessions;
}

std::optional<CalibrationSession> CalibrationDao::latestForSensor(int sensorId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT * FROM calibration_session WHERE sensor_id = :sensor_id "
        "ORDER BY id DESC LIMIT 1"));
    query.bindValue(QStringLiteral(":sensor_id"), sensorId);

    if (!query.exec()) {
        qWarning() << "CalibrationDao::latestForSensor:" << query.lastError().text();
        return std::nullopt;
    }
    if (!query.next())
        return std::nullopt;

    CalibrationSession session = rowToSession(query.record());
    session.points = pointsForSession(session.id);
    return session;
}

QList<CalibrationPoint> CalibrationDao::pointsForSession(int sessionId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT id, raw_value, reference_value, note FROM calibration_point "
        "WHERE session_id = :session_id ORDER BY id"));
    query.bindValue(QStringLiteral(":session_id"), sessionId);

    if (!query.exec()) {
        qWarning() << "CalibrationDao::pointsForSession:" << query.lastError().text();
        return {};
    }

    QList<CalibrationPoint> points;
    while (query.next()) {
        CalibrationPoint point;
        point.id             = query.value(QStringLiteral("id")).toInt();
        point.rawValue       = query.value(QStringLiteral("raw_value")).toDouble();
        point.referenceValue = query.value(QStringLiteral("reference_value")).toDouble();
        point.note           = query.value(QStringLiteral("note")).toString();
        points.append(point);
    }
    return points;
}

int CalibrationDao::countForSensor(int sensorId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM calibration_session WHERE sensor_id = :sensor_id"));
    query.bindValue(QStringLiteral(":sensor_id"), sensorId);

    if (!query.exec()) {
        qWarning() << "CalibrationDao::countForSensor:" << query.lastError().text();
        return -1;
    }
    return query.next() ? query.value(0).toInt() : -1;
}

bool CalibrationDao::removeSession(int id)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("DELETE FROM calibration_session WHERE id = :id"));
    query.bindValue(QStringLiteral(":id"), id);

    if (!query.exec()) {
        qWarning() << "CalibrationDao::removeSession:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}
