#pragma once
#include "data/models/ReportLog.h"
#include <QSqlDatabase>
#include <QString>
#include <QList>
#include <QDateTime>

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
