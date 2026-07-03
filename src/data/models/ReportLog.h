#pragma once
#include <QString>
#include <QDateTime>

struct ReportLog {
    int id = 0;
    QString filePath;
    QString remotePath;
    QString status = "pending";  // "pending" | "success" | "failed"
    int retryCount = 0;
    QDateTime createdAt;
    QDateTime updatedAt;
};
