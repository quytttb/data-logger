#include "DatabaseWorker.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDataDao.h"
#include <QDateTime>
#include <QFile>
#include <QSaveFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutexLocker>
#include <QDebug>
#include <utility>

namespace {
constexpr int kHeartbeatIntervalMs = 5000;  // liveness ping to MonitorController
}

DatabaseWorker::DatabaseWorker(QObject *parent) : QObject(parent) {}

void DatabaseWorker::setSpillPath(const QString &path) {
    m_spillPath = path;
}

void DatabaseWorker::enqueue(const QVariantMap &payload) {
    QMutexLocker lock(&m_mutex);
    if (!m_running) return;
    if (m_queue.size() >= kMaxQueueSize) {
        m_queue.dequeue();
        qWarning() << "DatabaseWorker: queue overflow — oldest record dropped";
    }
    m_queue.enqueue(payload);
}

void DatabaseWorker::start() {
    m_running = true;

    // Audit M4: pick up records that were spilled to disk by a previous
    // shutdown before any new payload lands. They go to the FRONT of the
    // queue to preserve chronological order.
    loadSpilledQueue();

    m_flushTimer = new QTimer(this);
    m_flushTimer->setInterval(kFlushIntervalMs);
    connect(m_flushTimer, &QTimer::timeout, this, &DatabaseWorker::flush);
    m_flushTimer->start();

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(kHeartbeatIntervalMs);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &DatabaseWorker::onHeartbeatTimer);
    m_heartbeatTimer->start();
}

void DatabaseWorker::stop() {
    m_running = false;
    if (m_flushTimer) m_flushTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();
    flush(); // drain remaining records
    // Audit M4: if the final flush could not write everything (DB error or
    // new arrivals during stop), spill the leftover queue to disk instead of
    // dropping it — the next start() re-injects these records.
    {
        QMutexLocker lock(&m_mutex);
        if (!m_queue.isEmpty()) {
            lock.unlock();
            saveSpilledQueue();
        }
    }
    emit workerStopped();
}

void DatabaseWorker::loadSpilledQueue() {
    if (m_spillPath.isEmpty()) return;
    QFile f(m_spillPath);
    if (!f.exists() || !f.open(QIODevice::ReadOnly)) return;
    const QByteArray raw = f.readAll();
    f.close();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        qWarning() << "DatabaseWorker: spill file corrupt, ignored:" << err.errorString();
        return;
    }
    // Không xóa file ngay — chỉ xóa sau khi batch chứa các record này được flush thành công.
    // Tránh mất dữ liệu nếu cắt điện giữa lúc load và flush chưa commit.
    int restored = 0;
    const QJsonArray arr = doc.array();
    for (int i = arr.size() - 1; i >= 0; --i) {
        const auto &v = arr.at(i);
        if (!v.isObject()) continue;
        m_queue.prepend(v.toObject().toVariantMap());
        ++restored;
    }
    m_spilledCount = restored;
    if (restored > 0)
        qInfo() << "DatabaseWorker: restored" << restored << "spilled records from disk";
}

void DatabaseWorker::saveSpilledQueue() {
    if (m_spillPath.isEmpty()) return;
    // Ghi bằng QSaveFile để cắt điện giữa lúc ghi không để lại file rỗng/corrupt.
    // Không merge với spill cũ trên đĩa nữa — queue hiện tại đã chứa m_spilledCount
    // record từ spill cũ (chưa xóa file), nên merge sẽ duplicate.
    QJsonArray array;
    {
        QMutexLocker lock(&m_mutex);
        for (const auto &item : std::as_const(m_queue))
            array.append(QJsonObject::fromVariantMap(item));
        // Giữ queue nguyên — chỉ clear sau khi commit thành công
    }
    if (array.isEmpty()) return;
    QSaveFile f(m_spillPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "DatabaseWorker: cannot write spill file" << m_spillPath;
        return;
    }
    f.write(QJsonDocument(array).toJson(QJsonDocument::Compact));
    if (!f.commit()) {
        qWarning() << "DatabaseWorker: spill commit failed" << m_spillPath;
        return;
    }
    // Commit ok mới clear queue
    {
        QMutexLocker lock(&m_mutex);
        m_queue.clear();
    }
    qInfo() << "DatabaseWorker: spilled" << array.size() << "unwritten records to" << m_spillPath;
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

    ScopedDbConnection db;
    if (!db.get().isOpen()) {
        QMutexLocker lock(&m_mutex);
        for (int i = batch.size() - 1; i >= 0; --i)
            m_queue.prepend(batch[i]);
        emit dbError("DatabaseWorker: cannot open connection — records requeued");
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
        const QVariant alarmVar = p.value(QStringLiteral("alarm_type"));
        d.alarmType = alarmVar.isNull() ? QString() : alarmVar.toString();
        QString ra  = p.value("recorded_at").toString();
        d.recordedAt = ra.isEmpty()
                       ? QDateTime::currentDateTime()
                       : QDateTime::fromString(ra, Qt::ISODate);
        records.append(d);
    }

    SensorDataDao dao(db);
    bool ok = dao.insertBatch(records);

    if (!ok) {
        QMutexLocker lock(&m_mutex);
        for (int i = batch.size() - 1; i >= 0; --i)
            m_queue.prepend(batch[i]);
        emit dbError("DatabaseWorker: batch insert failed — retrying next flush");
    } else {
        // Batch chứa spilled records đã được ghi — xóa spill file
        if (m_spilledCount > 0) {
            const int consumed = qMin(m_spilledCount, batch.size());
            m_spilledCount -= consumed;
            if (m_spilledCount == 0 && !m_spillPath.isEmpty()) {
                if (QFile::exists(m_spillPath))
                    QFile::remove(m_spillPath);
                qInfo() << "DatabaseWorker: spill file acknowledged and removed";
            }
        }
        emit recordsSaved(records.size());
    }
}
