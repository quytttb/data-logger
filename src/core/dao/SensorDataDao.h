#pragma once
#include "../../models/SensorData.h"
#include <QSqlDatabase>
#include <QList>
#include <QDateTime>

class SensorDataDao {
public:
    explicit SensorDataDao(QSqlDatabase db);

    // Insert a batch of readings (called from DatabaseWorker).
    bool insertBatch(const QList<SensorData> &records);

    // Query helpers for HistoryView
    QList<SensorData> query(int sensorId,
                            const QDateTime &from, const QDateTime &to,
                            int limit = 2000);

    // Cleanup old records (keep last N days)
    int deleteOlderThan(const QDateTime &cutoff);

private:
    QSqlDatabase m_db;
    SensorData rowToData(const class QSqlRecord &r);
};
