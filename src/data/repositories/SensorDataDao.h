#pragma once
#include "data/models/SensorData.h"
#include <QSqlDatabase>
#include <QList>
#include <QDateTime>

class SensorDataDao {
public:
    explicit SensorDataDao(QSqlDatabase db);

    // Insert a batch of readings (called from DatabaseWorker).
    bool insertBatch(const QList<SensorData> &records);

    // Query helpers for HistoryView (sensorId==0 → all sensors)
    QList<SensorData> query(int sensorId,
                            const QDateTime &from, const QDateTime &to,
                            int limit = 2000);

    // Cleanup old records (keep last N days)
    int deleteOlderThan(const QDateTime &cutoff);

    // Chunked variant (RetentionWorker) — deletes at most @p chunkSize rows per
    // transaction so a bulk purge never holds a write-lock on the WAL long
    // enough to stall the live writer. Returns total rows deleted.
    int deleteOlderThanChunked(const QDateTime &cutoff, int chunkSize);

private:
    QSqlDatabase m_db;
    SensorData rowToData(const class QSqlRecord &r);
};
