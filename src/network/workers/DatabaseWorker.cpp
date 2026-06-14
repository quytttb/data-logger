#include "DatabaseWorker.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDataDao.h"
#include <QDateTime>
#include <QMutexLocker>
#include <QDebug>
#include <utility>

DatabaseWorker::DatabaseWorker(QObject *parent) : QObject(parent) {}

void DatabaseWorker::enqueue(const QVariantMap &payload) {
    QMutexLocker lock(&m_mutex);
    m_queue.enqueue(payload);
}

void DatabaseWorker::start() {
    m_running = true;

    m_flushTimer = new QTimer(this);
    m_flushTimer->setInterval(kFlushIntervalMs);
    connect(m_flushTimer, &QTimer::timeout, this, &DatabaseWorker::flush);
    m_flushTimer->start();

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(5000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &DatabaseWorker::onHeartbeatTimer);
    m_heartbeatTimer->start();
}

void DatabaseWorker::stop() {
    m_running = false;
    if (m_flushTimer) m_flushTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();
    flush(); // drain remaining records
    emit workerStopped();
}

void DatabaseWorker::onHeartbeatTimer() {
    if (m_running) emit heartbeat("DatabaseWorker");
}

void DatabaseWorker::flush() {
    QQueue<QVariantMap> batch;
    {
        QMutexLocker lock(&m_mutex);
        batch.swap(m_queue);
    }
    if (batch.isEmpty()) return;

    auto db = Database::openConnection();
    if (!db.isOpen()) {
        emit dbError("DatabaseWorker: cannot open connection");
        return;
    }

    QList<SensorData> records;
    for (const auto &p : std::as_const(batch)) {
        SensorData d;
        d.sensorId  = p["sensor_id"].toInt();
        d.rawValue  = p.contains("raw_value") && !p["raw_value"].isNull()
                      ? std::optional<double>(p["raw_value"].toDouble()) : std::nullopt;
        d.value     = p.contains("value") && !p["value"].isNull()
                      ? std::optional<double>(p["value"].toDouble()) : std::nullopt;
        d.status    = p.value("status").toString();
        d.isAlarm   = p.value("is_alarm", false).toBool();
        d.alarmType = p.value("alarm_type").toString();
        QString ra  = p.value("recorded_at").toString();
        d.recordedAt = ra.isEmpty()
                       ? QDateTime::currentDateTime()
                       : QDateTime::fromString(ra, Qt::ISODate);
        records.append(d);
    }

    SensorDataDao dao(db);
    if (!dao.insertBatch(records))
        emit dbError("DatabaseWorker: batch insert failed");
    else
        emit recordsSaved(records.size());

    db.close();
}
