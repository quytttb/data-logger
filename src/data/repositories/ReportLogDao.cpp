#include "ReportLogDao.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>

ReportLogDao::ReportLogDao(QSqlDatabase db) : m_db(std::move(db)) {}

ReportLog ReportLogDao::rowToLog(const QSqlRecord &r) {
    ReportLog l;
    l.id         = r.value("id").toInt();
    l.filePath   = r.value("file_path").toString();
    l.remotePath = r.value("remote_path").toString();
    l.status     = r.value("status").toString();
    l.retryCount = r.value("retry_count").toInt();
    l.createdAt  = QDateTime::fromString(r.value("created_at").toString(), Qt::ISODate);
    l.updatedAt  = QDateTime::fromString(r.value("updated_at").toString(), Qt::ISODate);
    return l;
}

bool ReportLogDao::insert(ReportLog &log) {
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO report_log (file_path, remote_path, status) VALUES (:fp, :rp, :st)");
    q.bindValue(":fp", log.filePath);
    q.bindValue(":rp", log.remotePath);
    q.bindValue(":st", log.status);
    if (!q.exec()) return false;
    log.id = q.lastInsertId().toInt();
    return true;
}

bool ReportLogDao::updateStatus(int id, const QString &status, int retryCount) {
    QSqlQuery q(m_db);
    if (retryCount < 0) {
        q.prepare("UPDATE report_log SET status=:st, updated_at=datetime('now') WHERE id=:id");
    } else {
        q.prepare("UPDATE report_log SET status=:st, retry_count=:rc, updated_at=datetime('now') WHERE id=:id");
        q.bindValue(":rc", retryCount);
    }
    q.bindValue(":st", status);
    q.bindValue(":id", id);
    return q.exec();
}

QList<ReportLog> ReportLogDao::loadPending(int maxRetry) {
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM report_log WHERE status IN ('pending','failed') AND retry_count <= :mr ORDER BY created_at");
    q.bindValue(":mr", maxRetry);
    q.exec();
    QList<ReportLog> result;
    while (q.next())
        result.append(rowToLog(q.record()));
    return result;
}

bool ReportLogDao::resetFailedRetries() {
    QSqlQuery q(m_db);
    q.exec("UPDATE report_log SET retry_count=0 WHERE status='failed'");
    return !q.lastError().isValid();
}
