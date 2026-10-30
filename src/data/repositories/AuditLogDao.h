#pragma once
#include "data/models/AuditLogEntry.h"
#include <QList>
#include <QSqlDatabase>

// Ghi và truy vấn audit_log.
//
// append() KHÔNG tự mở transaction: caller phải bọc transaction của nghiệp vụ
// (vd lưu cấu hình cảm biến + ghi audit) để tránh "đã đổi dữ liệu nhưng không
// có dấu vết". Vì vậy khi nghiệp vụ rollback, audit cũng rollback theo.
class AuditLogDao {
public:
    explicit AuditLogDao(QSqlDatabase db);

    // Trả false nếu action rỗng hoặc INSERT lỗi. Gán entry.id khi thành công.
    bool append(AuditLogEntry &entry);

    QList<AuditLogEntry> query(const AuditLogQuery &filter) const;
    int count(const AuditLogQuery &filter) const;

    // Xóa log cũ hơn cutoff (retention). Trả số dòng đã xóa, -1 nếu lỗi.
    int purgeBefore(const QDateTime &cutoff);

private:
    QSqlDatabase m_db;
    static AuditLogEntry rowToEntry(const class QSqlRecord &record);
    // Dựng WHERE + bind dùng chung cho query()/count().
    static QString whereClause(const AuditLogQuery &filter, QVariantMap &binds);
};
