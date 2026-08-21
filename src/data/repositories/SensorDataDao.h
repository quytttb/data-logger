#pragma once
#include "data/models/SensorData.h"
#include <QSqlDatabase>
#include <QList>
#include <QDateTime>
#include <optional>

class SensorDataDao {
public:
    explicit SensorDataDao(QSqlDatabase db);

    // Insert a batch of readings (called from DatabaseWorker).
    bool insertBatch(const QList<SensorData> &records);

    // Query helpers for HistoryView (sensorId==0 → all sensors)
    QList<SensorData> query(int sensorId,
                            const QDateTime &from, const QDateTime &to,
                            int limit = 2000);

    // Aggregate một cửa sổ thời gian hoàn toàn trong SQL (SUM/COUNT) —
    // đúng kết quả với mọi số mẫu, không bị cap như tải N dòng về RAM.
    // Dùng cho báo cáo TT10 (audit H-6).
    struct WindowAggregate {
        int count = 0;                     // số mẫu có giá trị
        std::optional<double> average;     // AVG(value)
        QStringList distinctStatuses;      // các status xuất hiện trong cửa sổ
    };
    WindowAggregate aggregateWindow(int sensorId,
                                    const QDateTime &from, const QDateTime &to);

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
