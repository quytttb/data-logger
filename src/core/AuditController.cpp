#include "AuditController.h"

#include "AuthService.h"
#include "data/db/Database.h"
#include "data/db/TimeCodec.h"
#include "data/repositories/AuditLogDao.h"

#include <QtDebug>

IMPLEMENT_QML_SINGLETON(AuditController)

namespace {

QVariantList toVariantList(const QList<AuditLogEntry> &entries)
{
    QVariantList out;
    for (const AuditLogEntry &entry : entries) {
        const QString actor = !entry.actorDisplayName.isEmpty() ? entry.actorDisplayName
                              : !entry.actorUsername.isEmpty() ? entry.actorUsername
                              : auditActorKindToString(entry.actorKind);
        out.append(QVariantMap{
            {QStringLiteral("id"), entry.id},
            {QStringLiteral("occurredAt"), TimeCodec::toDb(entry.occurredAt)},
            {QStringLiteral("actorKind"), auditActorKindToString(entry.actorKind)},
            {QStringLiteral("actorUsername"), entry.actorUsername},
            {QStringLiteral("actor"), actor},
            {QStringLiteral("action"), entry.action},
            {QStringLiteral("entity"), entry.entity},
            {QStringLiteral("entityId"), entry.entityId},
            {QStringLiteral("result"), auditResultToString(entry.result)},
            {QStringLiteral("detailJson"), entry.detailJson},
        });
    }
    return out;
}

AuditResult resultFromFilter(const QString &value, bool *valid)
{
    *valid = true;
    if (value == QLatin1String("ok"))     return AuditResult::Ok;
    if (value == QLatin1String("denied")) return AuditResult::Denied;
    if (value == QLatin1String("failed")) return AuditResult::Failed;
    *valid = false;
    return AuditResult::Ok;
}

} // namespace

AuditController::AuditController(QObject *parent) : QObject(parent) {}

bool AuditController::allowed() const
{
    return AuthService::authorize(Permission::ViewAudit);
}

int AuditController::pageCount() const
{
    if (m_total <= 0)
        return 1;
    return (m_total + kPageSize - 1) / kPageSize;
}

void AuditController::setFilters(const QString &action, const QString &entity,
                                 const QString &result, int days)
{
    const QString newAction = action.trimmed();
    const QString newEntity = entity.trimmed();
    const QString newResult = result.trimmed();
    const int newDays = qMax(0, days);

    if (m_action == newAction && m_entity == newEntity && m_result == newResult
        && m_days == newDays) {
        return;
    }

    m_action = newAction;
    m_entity = newEntity;
    m_result = newResult;
    m_days = newDays;
    m_page = 0;
    emit filtersChanged();
    refresh();
}

void AuditController::setPage(int page)
{
    const int target = qBound(0, page, pageCount() - 1);
    if (target == m_page)
        return;
    m_page = target;
    reload();
    emit changed();
}

void AuditController::nextPage()
{
    setPage(m_page + 1);
}

void AuditController::previousPage()
{
    setPage(m_page - 1);
}

void AuditController::refresh()
{
    reload();
    emit changed();
}

QStringList AuditController::actionOptions() const
{
    if (!allowed())
        return {};
    ScopedDbConnection db;
    if (!db.get().isOpen())
        return {};
    AuditLogDao dao(db);
    return dao.distinctActions();
}

QStringList AuditController::entityOptions() const
{
    if (!allowed())
        return {};
    ScopedDbConnection db;
    if (!db.get().isOpen())
        return {};
    AuditLogDao dao(db);
    return dao.distinctEntities();
}

void AuditController::reload()
{
    m_entries = {};
    m_total = 0;
    if (!allowed())
        return;

    AuditLogQuery filter;
    filter.actionPrefix = m_action;
    filter.entity = m_entity;
    bool validResult = false;
    if (!m_result.isEmpty()) {
        const AuditResult result = resultFromFilter(m_result, &validResult);
        if (validResult)
            filter.result = result;
    }
    if (m_days > 0)
        filter.from = QDateTime::currentDateTimeUtc().addDays(-m_days);

    ScopedDbConnection db;
    if (!db.get().isOpen())
        return;
    AuditLogDao dao(db);

    const int total = dao.count(filter);
    m_total = qMax(0, total);
    m_page = qBound(0, m_page, pageCount() - 1);

    filter.limit = kPageSize;
    filter.offset = m_page * kPageSize;
    m_entries = toVariantList(dao.query(filter));
}
