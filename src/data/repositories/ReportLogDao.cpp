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

QList<ReportLog> ReportLogDao::loadOlderThan(const QDateTime &cutoff, int limit) {
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM report_log WHERE status='success' AND created_at < :cutoff "
              "ORDER BY created_at LIMIT :lim");
    q.bindValue(":cutoff", cutoff.toString(Qt::ISODate));
    q.bindValue(":lim", limit);
    q.exec();
    QList<ReportLog> result;
    while (q.next())
        result.append(rowToLog(q.record()));
    return result;
}

bool ReportLogDao::remove(int id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM report_log WHERE id=:id");
    q.bindValue(":id", id);
    return q.exec();
}

QDateTime ReportLogDao::lastGeneratedAt() {
    // H-6 fix: thời điểm sinh báo cáo gần nhất được persist trong report_log
    // (created_at) thay vì biến static — sống sót qua restart nên cửa sổ báo
    // cáo kế tiếp không bị overlap / mất dữ liệu sau khi khởi động lại.
    QSqlQuery q(m_db);
    if (!q.exec("SELECT MAX(created_at) FROM report_log"))
        return {};
    if (!q.next())
        return {};
    return QDateTime::fromString(q.value(0).toString(), Qt::ISODate);
}
