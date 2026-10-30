#pragma once
#include <QDateTime>
#include <QString>

// Vai trò cố định giai đoạn đầu — chưa thêm root hay quyền ngoài phạm vi khí thải.
enum class UserRole { Viewer, Operator, Admin };

inline UserRole userRoleFromString(const QString &role)
{
    if (role == QLatin1String("admin"))    return UserRole::Admin;
    if (role == QLatin1String("operator")) return UserRole::Operator;
    return UserRole::Viewer;
}

inline QString userRoleToString(UserRole role)
{
    switch (role) {
    case UserRole::Admin:    return QStringLiteral("admin");
    case UserRole::Operator: return QStringLiteral("operator");
    case UserRole::Viewer:   return QStringLiteral("viewer");
    }
    return QStringLiteral("viewer");
}

inline bool isKnownUserRole(const QString &role)
{
    return role == QLatin1String("viewer")
        || role == QLatin1String("operator")
        || role == QLatin1String("admin");
}

struct UserAccount {
    int id = 0;
    QString username;
    QString displayName;
    UserRole role = UserRole::Viewer;
    QString passwordHash;
    bool active = true;
    bool mustChangePassword = false;
    int failedAttempts = 0;
    QDateTime lockedUntil;   // invalid = không khóa
    QDateTime lastLoginAt;   // invalid = chưa đăng nhập
    QDateTime createdAt;
    QDateTime updatedAt;
};
