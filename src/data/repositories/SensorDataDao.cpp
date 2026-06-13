#include "SensorDataDao.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>
#include <QDebug>

SensorDataDao::SensorDataDao(QSqlDatabase db) : m_db(std::move(db)) {}

SensorData SensorDataDao::rowToData(const QSqlRecord &r) {
    SensorData d;
    d.id        = r.value("id").toInt();
    d.sensorId  = r.value("sensor_id").toInt();
    if (!r.value("raw_value").isNull()) d.rawValue = r.value("raw_value").toDouble();
    if (!r.value("value").isNull())     d.value    = r.value("value").toDouble();
    d.status    = r.value("status").toString();
    d.isAlarm   = r.value("is_alarm").toBool();
    d.alarmType = r.value("alarm_type").toString();
    d.recordedAt= QDateTime::fromString(r.value("recorded_at").toString(), Qt::ISODate);
    return d;
}

bool SensorDataDao::insertBatch(const QList<SensorData> &records) {
    if (records.isEmpty()) return true;

    m_db.transaction();
    QSqlQuery q(m_db);
    q.prepare(R"(INSERT INTO sensor_data
        (sensor_id, raw_value, value, status, is_alarm, alarm_type, recorded_at)
        VALUES (:sid, :rv, :v, :st, :ia, :at, :ra))");

    for (const SensorData &d : records) {
        q.bindValue(":sid", d.sensorId);
        q.bindValue(":rv",  d.rawValue.has_value() ? QVariant(*d.rawValue) : QVariant());
        q.bindValue(":v",   d.value.has_value() ? QVariant(*d.value) : QVariant());
        q.bindValue(":st",  d.status);
        q.bindValue(":ia",  d.isAlarm ? 1 : 0);
        q.bindValue(":at",  d.alarmType);
        q.bindValue(":ra",  d.recordedAt.toString(Qt::ISODate));
        if (!q.exec()) {
            qWarning() << "SensorDataDao::insertBatch error:" << q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    m_db.commit();
    return true;
}

QList<SensorData> SensorDataDao::query(int sensorId,
                                        const QDateTime &from, const QDateTime &to,
                                        int limit) {
    QSqlQuery q(m_db);
    q.prepare(R"(SELECT * FROM sensor_data
        WHERE sensor_id=:sid AND recorded_at BETWEEN :f AND :t
        ORDER BY recorded_at DESC LIMIT :lim)");
    q.bindValue(":sid", sensorId);
    q.bindValue(":f",   from.toString(Qt::ISODate));
    q.bindValue(":t",   to.toString(Qt::ISODate));
    q.bindValue(":lim", limit);
    q.exec();

    QList<SensorData> result;
    while (q.next())
        result.prepend(rowToData(q.record()));
    return result;
}

int SensorDataDao::deleteOlderThan(const QDateTime &cutoff) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sensor_data WHERE recorded_at < :cutoff");
    q.bindValue(":cutoff", cutoff.toString(Qt::ISODate));
    q.exec();
    return q.numRowsAffected();
}
