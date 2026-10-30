#pragma once
#include <QDateTime>
#include <QString>
#include <optional>

// Actor của một sự kiện audit. local = tài khoản kiosk; system = tiến trình
// nền (retention, FTP, ...); remote_device = Central gọi REST/Modbus.
enum class AuditActorKind { Local, System, RemoteDevice };

inline AuditActorKind auditActorKindFromString(const QString &kind)
{
    if (kind == QLatin1String("local"))         return AuditActorKind::Local;
    if (kind == QLatin1String("remote_device")) return AuditActorKind::RemoteDevice;
    return AuditActorKind::System;
}

inline QString auditActorKindToString(AuditActorKind kind)
{
    switch (kind) {
    case AuditActorKind::Local:        return QStringLiteral("local");
    case AuditActorKind::RemoteDevice: return QStringLiteral("remote_device");
    case AuditActorKind::System:       return QStringLiteral("system");
    }
    return QStringLiteral("system");
}

enum class AuditResult { Ok, Denied, Failed };

inline AuditResult auditResultFromString(const QString &result)
{
    if (result == QLatin1String("denied")) return AuditResult::Denied;
    if (result == QLatin1String("failed")) return AuditResult::Failed;
    return AuditResult::Ok;
}

inline QString auditResultToString(AuditResult result)
{
    switch (result) {
    case AuditResult::Denied: return QStringLiteral("denied");
    case AuditResult::Failed: return QStringLiteral("failed");
    case AuditResult::Ok:     return QStringLiteral("ok");
    }
    return QStringLiteral("ok");
}

struct AuditLogEntry {
    int id = 0;
    QDateTime occurredAt;
    AuditActorKind actorKind = AuditActorKind::System;
    int actorUserId = 0;                 // 0 = không gắn tài khoản (system/remote)
    QString actorUsername = QStringLiteral("");   // snapshot — giữ khi user đổi tên/bị xóa
    QString actorDisplayName = QStringLiteral(""); // snapshot
    QString action = QStringLiteral("");            // vd: "sensor.update", "calibration.apply"
    QString entity = QStringLiteral("");            // vd: "sensor", "app_config", "user"
    QString entityId = QStringLiteral("");
    AuditResult result = AuditResult::Ok;
    QString detailJson = QStringLiteral("{}");
};

struct AuditLogQuery {
    QString actionPrefix;                // rỗng = tất cả
    QString entity;                      // rỗng = tất cả
    std::optional<AuditResult> result;
    QDateTime from;                      // invalid = không giới hạn dưới
    QDateTime to;                        // invalid = không giới hạn trên (loại trừ mốc)
    int limit = 100;
    int offset = 0;
};
