#pragma once
#include <QDateTime>
#include <QString>
#include <QVariant>

// Chuyển QDateTime ↔ TEXT trong SQLite. Mọi mốc thời gian lưu UTC dạng
// ISO-8601 có mili-giây (vd 2026-10-30T07:12:33.123Z) để so sánh chuỗi
// theo thứ tự thời gian và đọc được trực tiếp bằng sqlite3.
namespace TimeCodec {

inline QString toDb(const QDateTime &dt)
{
    return dt.toUTC().toString(Qt::ISODateWithMs);
}

inline QDateTime fromDb(const QVariant &value)
{
    if (!value.isValid() || value.isNull())
        return {};
    return QDateTime::fromString(value.toString(), Qt::ISODateWithMs);
}

inline QVariant toDbOrNull(const QDateTime &dt)
{
    return dt.isValid() ? QVariant(toDb(dt)) : QVariant();
}

} // namespace TimeCodec
