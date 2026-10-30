#include "AuditLogDao.h"
#include "data/db/TimeCodec.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStringList>
#include <QVariantMap>
#include <QtDebug>

namespace {

// QString() mặc định là null -> Qt bind thành NULL, vi phạm cột NOT NULL.
QString textOrEmpty(const QString &value)
{
    return value.isNull() ? QStringLiteral("") : value;
}

} // namespace

AuditLogDao::AuditLogDao(QSqlDatabase db) : m_db(std::move(db)) {}

AuditLogEntry AuditLogDao::rowToEntry(const QSqlRecord &record)
{
    AuditLogEntry entry;
    entry.id               = record.value(QStringLiteral("id")).toInt();
    entry.occurredAt       = TimeCodec::fromDb(record.value(QStringLiteral("occurred_at")));
    entry.actorKind        = auditActorKindFromString(record.value(QStringLiteral("actor_kind")).toString());
    entry.actorUserId      = record.value(QStringLiteral("actor_user_id")).toInt();
    entry.actorUsername    = record.value(QStringLiteral("actor_username")).toString();
    entry.actorDisplayName = record.value(QStringLiteral("actor_display_name")).toString();
    entry.action           = record.value(QStringLiteral("action")).toString();
    entry.entity           = record.value(QStringLiteral("entity")).toString();
    entry.entityId         = record.value(QStringLiteral("entity_id")).toString();
    entry.result           = auditResultFromString(record.value(QStringLiteral("result")).toString());
    entry.detailJson       = record.value(QStringLiteral("detail_json")).toString();
    return entry;
}

bool AuditLogDao::append(AuditLogEntry &entry)
{
    if (entry.action.trimmed().isEmpty()) {
        qWarning() << "AuditLogDao::append: action rỗng — từ chối ghi";
        return false;
    }
    if (!entry.occurredAt.isValid())
        entry.occurredAt = QDateTime::currentDateTimeUtc();

    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO audit_log
            (occurred_at, actor_kind, actor_user_id, actor_username, actor_display_name,
             action, entity, entity_id, result, detail_json)
        VALUES
            (:occurred_at, :actor_kind, :actor_user_id, :actor_username, :actor_display_name,
             :action, :entity, :entity_id, :result, :detail_json))");
    query.bindValue(QStringLiteral(":occurred_at"), TimeCodec::toDb(entry.occurredAt));
    query.bindValue(QStringLiteral(":actor_kind"), auditActorKindToString(entry.actorKind));
    query.bindValue(QStringLiteral(":actor_user_id"),
                    entry.actorUserId > 0 ? QVariant(entry.actorUserId) : QVariant());
    query.bindValue(QStringLiteral(":actor_username"), textOrEmpty(entry.actorUsername));
    query.bindValue(QStringLiteral(":actor_display_name"), textOrEmpty(entry.actorDisplayName));
    query.bindValue(QStringLiteral(":action"), entry.action.trimmed());
    query.bindValue(QStringLiteral(":entity"), textOrEmpty(entry.entity));
    query.bindValue(QStringLiteral(":entity_id"), textOrEmpty(entry.entityId));
    query.bindValue(QStringLiteral(":result"), auditResultToString(entry.result));
    query.bindValue(QStringLiteral(":detail_json"),
                    entry.detailJson.trimmed().isEmpty() ? QStringLiteral("{}") : entry.detailJson);

    if (!query.exec()) {
        qWarning() << "AuditLogDao::append:" << query.lastError().text();
        return false;
    }

    entry.id = query.lastInsertId().toInt();
    return entry.id > 0;
}

QString AuditLogDao::whereClause(const AuditLogQuery &filter, QVariantMap &binds)
{
    QStringList conditions;

    if (!filter.actionPrefix.trimmed().isEmpty()) {
        conditions << QStringLiteral("action LIKE :action_prefix");
        binds.insert(QStringLiteral(":action_prefix"), filter.actionPrefix.trimmed() + QLatin1Char('%'));
    }
    if (!filter.entity.trimmed().isEmpty()) {
        conditions << QStringLiteral("entity = :entity");
        binds.insert(QStringLiteral(":entity"), filter.entity.trimmed());
    }
    if (filter.result.has_value()) {
        conditions << QStringLiteral("result = :result");
        binds.insert(QStringLiteral(":result"), auditResultToString(*filter.result));
    }
    if (filter.from.isValid()) {
        conditions << QStringLiteral("occurred_at >= :from");
        binds.insert(QStringLiteral(":from"), TimeCodec::toDb(filter.from));
    }
    if (filter.to.isValid()) {
        conditions << QStringLiteral("occurred_at < :to");
        binds.insert(QStringLiteral(":to"), TimeCodec::toDb(filter.to));
    }

    return conditions.isEmpty() ? QString() : QStringLiteral(" WHERE ") + conditions.join(QStringLiteral(" AND "));
}

QList<AuditLogEntry> AuditLogDao::query(const AuditLogQuery &filter) const
{
    QVariantMap binds;
    const QString where = whereClause(filter, binds);
    const int limit = qBound(1, filter.limit, 1000);
    const int offset = qMax(0, filter.offset);

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("SELECT * FROM audit_log") + where
                  + QStringLiteral(" ORDER BY id DESC LIMIT :limit OFFSET :offset"));
    for (auto it = binds.cbegin(); it != binds.cend(); ++it)
        query.bindValue(it.key(), it.value());
    query.bindValue(QStringLiteral(":limit"), limit);
    query.bindValue(QStringLiteral(":offset"), offset);

    if (!query.exec()) {
        qWarning() << "AuditLogDao::query:" << query.lastError().text();
        return {};
    }

    QList<AuditLogEntry> entries;
    while (query.next())
        entries.append(rowToEntry(query.record()));
    return entries;
}

int AuditLogDao::count(const AuditLogQuery &filter) const
{
    QVariantMap binds;
    const QString where = whereClause(filter, binds);

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("SELECT COUNT(*) FROM audit_log") + where);
    for (auto it = binds.cbegin(); it != binds.cend(); ++it)
        query.bindValue(it.key(), it.value());

    if (!query.exec()) {
        qWarning() << "AuditLogDao::count:" << query.lastError().text();
        return -1;
    }
    return query.next() ? query.value(0).toInt() : -1;
}

int AuditLogDao::purgeBefore(const QDateTime &cutoff)
{
    if (!cutoff.isValid())
        return -1;

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("DELETE FROM audit_log WHERE occurred_at < :cutoff"));
    query.bindValue(QStringLiteral(":cutoff"), TimeCodec::toDb(cutoff));

    if (!query.exec()) {
        qWarning() << "AuditLogDao::purgeBefore:" << query.lastError().text();
        return -1;
    }
    return query.numRowsAffected();
}
