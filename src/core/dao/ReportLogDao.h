#pragma once
#include <QSqlDatabase>
#include <QString>
#include <QList>
#include <QDateTime>

struct ReportLog {
    int id = 0;
    QString filePath;
    QString status = "pending";  // "pending" | "success" | "failed"
    int retryCount = 0;
    QDateTime createdAt;
    QDateTime updatedAt;
};

class ReportLogDao {
public:
    explicit ReportLogDao(QSqlDatabase db);

    bool insert(ReportLog &log);
    bool updateStatus(int id, const QString &status, int retryCount = -1);
    QList<ReportLog> loadPending(int maxRetry = 5);
    bool resetFailedRetries();

private:
    QSqlDatabase m_db;
    ReportLog rowToLog(const class QSqlRecord &r);
};
