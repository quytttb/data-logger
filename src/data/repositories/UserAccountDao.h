#pragma once
#include "data/models/UserAccount.h"
#include <QList>
#include <QSqlDatabase>
#include <optional>

// Truy cập bảng user_account. Không chứa chính sách đăng nhập (khóa tài khoản,
// giới hạn số lần sai) — phần đó thuộc AuthService ở Slice 1.
class UserAccountDao {
public:
    explicit UserAccountDao(QSqlDatabase db);

    QList<UserAccount> loadAll();
    int count() const;
    std::optional<UserAccount> findById(int id) const;
    std::optional<UserAccount> findByUsername(const QString &username) const;

    // Insert và gán user.id. Trả false nếu username trùng (UNIQUE NOCASE).
    bool insert(UserAccount &user);

    // Cập nhật hồ sơ + trạng thái + hash hiện tại. Không dùng cho đổi mật khẩu
    // riêng lẻ (xem updatePasswordHash).
    bool update(const UserAccount &user);
    bool updatePasswordHash(int id, const QString &hash, bool mustChangePassword);
    bool setActive(int id, bool active);
    bool setRole(int id, UserRole role);
    bool updateDetails(int id, const QString &displayName, UserRole role, bool active);
    bool remove(int id);

    // Ghi kết quả đăng nhập. AuthService quyết định ngưỡng/khóa, DAO chỉ lưu.
    bool updateLoginState(int id, int failedAttempts, const QDateTime &lockedUntil);
    bool recordLoginSuccess(int id);

    // Bảo vệ "admin cuối cùng": AuthService gọi trước khi hạ quyền/tắt/xóa.
    int countActiveAdmins() const;
    bool usernameExists(const QString &username, int excludeId = 0) const;

private:
    QSqlDatabase m_db;
    static UserAccount rowToUser(const class QSqlRecord &record);
};
