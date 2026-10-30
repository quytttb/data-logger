#include "AuditTrail.h"

#include "AuthService.h"
#include "data/db/Database.h"
#include "data/repositories/AuditLogDao.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QtDebug>

namespace AuditTrail {

Actor localActor()
{
    Actor actor;
    AuthService *auth = AuthService::instance();
    if (!auth || !auth->authenticated())
        return actor; // system: chưa có phiên người dùng

    actor.kind = AuditActorKind::Local;
    actor.userId = auth->currentUserId();
    actor.username = auth->currentUsername();
    actor.displayName = auth->currentDisplayName();
    return actor;
}

AuditLogEntry entry(const Actor &actor, const QString &action, const QString &entity,
                    const QString &entityId, AuditResult result, const QJsonObject &detail)
{
    AuditLogEntry out;
    out.occurredAt = QDateTime::currentDateTimeUtc();
    out.actorKind = actor.kind;
    out.actorUserId = actor.userId;
    out.actorUsername = actor.username;
    out.actorDisplayName = actor.displayName;
    out.action = action;
    out.entity = entity;
    out.entityId = entityId;
    out.result = result;
    out.detailJson = QString::fromUtf8(QJsonDocument(detail).toJson(QJsonDocument::Compact));
    return out;
}

bool append(QSqlDatabase &db, AuditLogEntry &entry)
{
    AuditLogDao dao(db);
    return dao.append(entry);
}

bool appendStandalone(const AuditLogEntry &entry)
{
    ScopedDbConnection db;
    if (!db.get().isOpen()) {
        qWarning() << "AuditTrail: bỏ qua sự kiện" << entry.action << "— DB chưa mở";
        return false;
    }
    AuditLogEntry copy = entry;
    AuditLogDao dao(db);
    return dao.append(copy);
}

QJsonObject changes(std::initializer_list<Change> items)
{
    QJsonObject fields;
    for (const Change &item : items) {
        const QJsonValue before = QJsonValue::fromVariant(item.before);
        const QJsonValue after = QJsonValue::fromVariant(item.after);
        if (before == after)
            continue;
        fields.insert(item.field,
                      QJsonObject{{QStringLiteral("from"), before},
                                  {QStringLiteral("to"), after}});
    }
    if (fields.isEmpty())
        return {};
    return QJsonObject{{QStringLiteral("changes"), fields}};
}

QJsonObject snapshot(std::initializer_list<std::pair<QString, QVariant>> fields)
{
    QJsonObject out;
    for (const auto &field : fields)
        out.insert(field.first, QJsonValue::fromVariant(field.second));
    return out;
}

QString safeCoefficient(const QString &json)
{
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject())
        return QStringLiteral("[advanced JSON omitted]");
    const QJsonObject obj = doc.object();
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        if ((it.key() != QLatin1String("a") && it.key() != QLatin1String("b"))
            || !it.value().isDouble())
            return QStringLiteral("[advanced JSON omitted]");
    }
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

} // namespace AuditTrail
