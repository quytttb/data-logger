#pragma once

#include "data/models/AuditLogEntry.h"

#include <QJsonObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariant>

#include <initializer_list>
#include <utility>

// Ghi audit log cho thao tác người dùng trên kiosk.
//
// Nguyên tắc:
// - Actor được chụp (snapshot) trên UI thread rồi truyền vào worker. Không đọc
//   AuthService từ thread khác.
// - append() KHÔNG tự mở transaction: caller bọc transaction nghiệp vụ để thay
//   đổi dữ liệu và dấu vết audit cùng commit/rollback.
// - detail chỉ chứa trường whitelist. KHÔNG đưa mật khẩu/hash, REST token, mật
//   khẩu FTP, QR hay dữ liệu nhạy cảm tương tự vào đây.
namespace AuditTrail {

struct Actor {
    AuditActorKind kind = AuditActorKind::System;
    int userId = 0;
    QString username;
    QString displayName;
};

struct Change {
    QString field;
    QVariant before;
    QVariant after;
};

// Snapshot phiên đăng nhập hiện tại (chỉ gọi trên UI thread).
Actor localActor();

AuditLogEntry entry(const Actor &actor, const QString &action, const QString &entity,
                    const QString &entityId = QString(),
                    AuditResult result = AuditResult::Ok,
                    const QJsonObject &detail = QJsonObject());

// Ghi trong transaction của caller. Trả false nếu INSERT lỗi để caller rollback
// nghiệp vụ — không được báo thành công khi thiếu dấu vết.
bool append(QSqlDatabase &db, AuditLogEntry &entry);

// Ghi sự kiện độc lập (đăng nhập/đăng xuất, bị từ chối quyền). Tự mở
// connection riêng; lỗi chỉ cảnh báo và trả false, không làm hỏng luồng chính.
bool appendStandalone(const AuditLogEntry &entry);

// {"changes": {"<field>": {"from": ..., "to": ...}}} — bỏ cặp không đổi.
QJsonObject changes(std::initializer_list<Change> items);
// {"<field>": ...} cho sự kiện tạo/xóa hoặc ngữ cảnh kèm theo.
QJsonObject snapshot(std::initializer_list<std::pair<QString, QVariant>> fields);

} // namespace AuditTrail
