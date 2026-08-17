#include "RetentionWorker.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDataDao.h"
#include "data/repositories/ReportLogDao.h"
#include "utils/system/AppPaths.h"
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QSqlQuery>
#include <QStorageInfo>
#include <QDebug>

RetentionWorker::RetentionWorker(QObject *parent) : QObject(parent) {}

void RetentionWorker::start() {
    if (m_purgeTimer) return;
    m_purgeTimer = new QTimer(this);
    m_purgeTimer->setSingleShot(false);
    m_purgeTimer->setInterval(kPurgeIntervalMs);
    connect(m_purgeTimer, &QTimer::timeout, this, &RetentionWorker::purge);
    m_purgeTimer->start(kFirstPurgeDelayMs); // lần đầu sau 1 phút, sau đó hằng ngày
}

void RetentionWorker::stop() {
    if (m_purgeTimer) {
        m_purgeTimer->stop();
        m_purgeTimer->deleteLater();
        m_purgeTimer = nullptr;
    }
}

void RetentionWorker::purge() {
    const QDateTime now = QDateTime::currentDateTime();

    int sensorRows = 0;
    int reports = 0;
    {
        ScopedDbConnection db;
        if (db.get().isOpen()) {
            SensorDataDao sdDao(db);
            sensorRows = purgeSensorData(sdDao, now.addDays(-kSensorDataKeepDays));
            ReportLogDao rDao(db);
            reports = purgeReportLogs(rDao, now.addDays(-kReportKeepDays));
            // Co file DB sau khi xóa số lượng lớn (WAL không tự co).
            QSqlQuery q(db);
            q.exec("PRAGMA wal_checkpoint(TRUNCATE);");
        }
    }

    pruneLogFiles(now.addDays(-kLogKeepDays));
    checkDiskSpace();

    if (sensorRows > 0 || reports > 0)
        qInfo() << "RetentionWorker: purged" << sensorRows << "sensor rows,"
                << reports << "report logs";
    emit purgeCompleted(sensorRows, reports);
}

int RetentionWorker::purgeSensorData(SensorDataDao &dao, const QDateTime &cutoff) {
    return dao.deleteOlderThanChunked(cutoff, kPurgeChunk);
}

int RetentionWorker::purgeReportLogs(ReportLogDao &dao, const QDateTime &cutoff) {
    int deleted = 0;
    const auto old = dao.loadOlderThan(cutoff);
    for (const auto &log : old) {
        if (dao.remove(log.id)) {
            QFile::remove(log.filePath); // đã upload thành công → xóa file local
            ++deleted;
        }
    }
    return deleted;
}

void RetentionWorker::pruneLogFiles(const QDateTime &cutoff) {
    QDir dir(AppPaths::logDir());
    const auto logs = dir.entryInfoList({"*.log"}, QDir::Files);
    for (const auto &fi : logs) {
        if (fi.lastModified() < cutoff)
            QFile::remove(fi.absoluteFilePath());
    }
}

void RetentionWorker::checkDiskSpace() {
    QStorageInfo info(AppPaths::dataDir());
    const qint64 free = info.bytesAvailable();
    if (free > 0 && free < kLowDiskBytes) {
        if (!m_lowDiskWarned) {
            m_lowDiskWarned = true;
            qCritical() << "RetentionWorker: low disk space:" << free << "bytes free in"
                        << info.rootPath();
            emit lowDiskSpace(free);
        }
    } else {
        m_lowDiskWarned = false;
    }
}
