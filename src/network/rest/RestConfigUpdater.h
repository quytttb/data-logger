#pragma once

#include <QJsonObject>
#include <QSqlDatabase>
#include <QString>

// Ghi cấu hình từ thiết bị Central, không gắn nhầm danh tính tài khoản kiosk.
// Cấu hình và audit được commit cùng transaction; không thay contract REST v1.
namespace RestConfigUpdater {

enum class Status { Ok, BadRequest, StorageError };

struct Result {
    Status status = Status::StorageError;
    QString error;
    int revision = 0;
};

// Caller sở hữu connection, không mở ScopedDbConnection lồng.
Result apply(QSqlDatabase &db, const QJsonObject &body, const QString &peerAddress);

} // namespace RestConfigUpdater
