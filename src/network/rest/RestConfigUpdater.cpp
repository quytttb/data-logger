#include "RestConfigUpdater.h"

#include "data/models/AuditLogEntry.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/AuditLogDao.h"
#include "utils/modbus/ModbusCodec.h"

#include <QJsonDocument>
#include <QRegularExpression>
#include <limits>

namespace RestConfigUpdater {

namespace {

Result badRequest(const QString &error)
{
    return {Status::BadRequest, error, 0};
}

QJsonObject changes(const AppConfig &before, const AppConfig &after)
{
    QJsonObject fields;
    const auto add = [&fields](const QString &key, const QJsonValue &oldValue,
                               const QJsonValue &newValue) {
        if (oldValue != newValue)
            fields.insert(key, QJsonObject{{QStringLiteral("from"), oldValue},
                                           {QStringLiteral("to"), newValue}});
    };
    // Whitelist đúng các trường POST cho phép; không chép request/token/secret.
    add(QStringLiteral("stationCode"), before.stationCode, after.stationCode);
    add(QStringLiteral("stationName"), before.stationName, after.stationName);
    add(QStringLiteral("pollInterval"), before.pollInterval, after.pollInterval);
    add(QStringLiteral("serialPort"), before.serialPort, after.serialPort);
    add(QStringLiteral("serialBaudrate"), before.serialBaudrate, after.serialBaudrate);
    return {{QStringLiteral("changes"), fields}};
}

} // namespace

Result apply(QSqlDatabase &db, const QJsonObject &body, const QString &peerAddress)
{
    // Giữ nguyên tập trường và quy tắc xác thực dữ liệu của REST v1.
    if (body.contains(QStringLiteral("poll_interval"))) {
        const int interval = body.value(QStringLiteral("poll_interval")).toInt(-1);
        if (interval < 1 || interval > 3600)
            return badRequest(QStringLiteral("poll_interval must be 1..3600 seconds"));
    }
    if (body.contains(QStringLiteral("serial_baudrate"))
        && !ModbusCodec::isSupportedBaudrate(body.value(QStringLiteral("serial_baudrate")).toInt(-1)))
        return badRequest(QStringLiteral("serial_baudrate is not supported"));
    if (body.contains(QStringLiteral("serial_port"))) {
        static const QRegularExpression re(QStringLiteral("^/dev/tty[A-Za-z0-9_.-]{1,64}$"));
        if (!re.match(body.value(QStringLiteral("serial_port")).toString().trimmed()).hasMatch())
            return badRequest(QStringLiteral("serial_port must be a /dev/tty* device path"));
    }
    if (body.contains(QStringLiteral("station_code"))
        && body.value(QStringLiteral("station_code")).toString().trimmed().isEmpty())
        return badRequest(QStringLiteral("station_code must not be empty"));

    const Result storageError{Status::StorageError, QStringLiteral("Configuration save failed"), 0};
    if (!db.isOpen() || !db.transaction())
        return storageError;

    AppConfigDao configDao(db);
    const AppConfig before = configDao.load();
    if (before.id <= 0 || before.configRevision == std::numeric_limits<int>::max()) {
        db.rollback();
        return storageError;
    }
    AppConfig after = before;
    if (body.contains(QStringLiteral("poll_interval")))
        after.pollInterval = body.value(QStringLiteral("poll_interval")).toInt();
    if (body.contains(QStringLiteral("serial_baudrate")))
        after.serialBaudrate = body.value(QStringLiteral("serial_baudrate")).toInt();
    if (body.contains(QStringLiteral("station_name")))
        after.stationName = body.value(QStringLiteral("station_name")).toString();
    if (body.contains(QStringLiteral("serial_port")))
        after.serialPort = body.value(QStringLiteral("serial_port")).toString().trimmed();
    if (body.contains(QStringLiteral("station_code")))
        after.stationCode = body.value(QStringLiteral("station_code")).toString().trimmed();
    ++after.configRevision;

    AuditLogEntry entry;
    entry.occurredAt = QDateTime::currentDateTimeUtc();
    entry.actorKind = AuditActorKind::RemoteDevice;
    entry.actorUsername = peerAddress.isNull() ? QStringLiteral("") : peerAddress;
    entry.actorDisplayName = QStringLiteral("REST device");
    entry.action = QStringLiteral("settings.remote_save");
    entry.entity = QStringLiteral("app_config");
    entry.entityId = QString::number(before.id);
    entry.detailJson = QString::fromUtf8(QJsonDocument(changes(before, after))
                                             .toJson(QJsonDocument::Compact));
    AuditLogDao auditDao(db);
    const bool ok = configDao.save(after) && auditDao.append(entry) && db.commit();
    if (!ok) {
        db.rollback();
        return storageError;
    }
    return {Status::Ok, {}, after.configRevision};
}

} // namespace RestConfigUpdater
