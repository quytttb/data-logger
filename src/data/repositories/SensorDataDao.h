#pragma once
#include "data/models/SensorData.h"
#include "utils/chart/Downsampler.h"
#include <QSqlDatabase>
#include <QList>
#include <QVector>
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

    // Chuỗi điểm cho trending graph lịch sử: ASC theo recorded_at, không
    // LIMIT theo số dòng hiển thị (downsampler mới là limiter) — chỉ chặn
    // trần maxRows để chống tràn RAM khi cửa sổ quá lớn. Vượt trần thì
    // truncated = true (giữ maxRows điểm CŨ nhất), caller phải báo UI.
    struct ChartSeries {
        int sensorId = 0;
        QVector<TrendPoint> points; // ASC theo recorded_at
        QVector<char> isAlarm;      // song song với points (1 = báo động)
        bool truncated = false;     // true = cửa sổ vượt maxRows, đã cắt bớt
    };
    ChartSeries queryRangeForChart(int sensorId,
                                   const QDateTime &from, const QDateTime &to,
                                   int maxRows = 200000);

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
