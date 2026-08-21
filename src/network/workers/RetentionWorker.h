#pragma once
#include <QDateTime>
#include <QObject>
#include <QTimer>

class SensorDataDao;
class ReportLogDao;

// Chạy trên thread riêng: dọn dẹp định kỳ để tránh đầy đĩa (SD card) trên
// thiết bị 24/7 — lỗi phổ biến nhất của logger sản xuất:
//  - sensor_data cũ hơn ngưỡng giữ (xóa theo chunk để không khóa DB lâu)
//  - report_log đã upload thành công + file TXT local tương ứng
//  - file log cũ trong thư mục logs
//  - theo dõi dung lượng đĩa trống, cảnh báo khi sắp hết
class RetentionWorker : public QObject {
    Q_OBJECT

public:
    explicit RetentionWorker(QObject *parent = nullptr);

signals:
    void purgeCompleted(int sensorRowsDeleted, int reportsDeleted);
    void lowDiskSpace(qint64 freeBytes);

public slots:
    void start();
    void stop();

private slots:
    void purge();

private:
    int purgeSensorData(SensorDataDao &dao, const QDateTime &cutoff);
    int purgeReportLogs(ReportLogDao &dao, const QDateTime &cutoff);
    void pruneLogFiles(const QDateTime &cutoff);
    void checkDiskSpace();

    QTimer *m_purgeTimer = nullptr;

    static constexpr int kFirstPurgeDelayMs = 60 * 1000;         // 1 phút sau khởi động
    static constexpr int kPurgeIntervalMs   = 24 * 60 * 60 * 1000; // hằng ngày
    static constexpr int kSensorDataKeepDays = 90;
    static constexpr int kReportKeepDays     = 30;  // báo cáo đã upload: giữ local 30 ngày
    static constexpr int kLogKeepDays        = 14;
    static constexpr int kPurgeChunk         = 50000;
    static constexpr qint64 kLowDiskBytes    = 100LL * 1024 * 1024; // cảnh báo dưới 100MB

    bool m_lowDiskWarned = false;
};
