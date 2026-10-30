#include "UserAccountDao.h"
#include "data/db/TimeCodec.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QtDebug>

UserAccountDao::UserAccountDao(QSqlDatabase db) : m_db(std::move(db)) {}

UserAccount UserAccountDao::rowToUser(const QSqlRecord &record)
{
    UserAccount user;
    user.id                 = record.value(QStringLiteral("id")).toInt();
    user.username           = record.value(QStringLiteral("username")).toString();
    user.displayName        = record.value(QStringLiteral("display_name")).toString();
    user.role               = userRoleFromString(record.value(QStringLiteral("role")).toString());
    user.passwordHash       = record.value(QStringLiteral("password_hash")).toString();
    user.active             = record.value(QStringLiteral("active")).toBool();
    user.mustChangePassword = record.value(QStringLiteral("must_change_password")).toBool();
    user.failedAttempts     = record.value(QStringLiteral("failed_attempts")).toInt();
    user.lockedUntil        = TimeCodec::fromDb(record.value(QStringLiteral("locked_until")));
    user.lastLoginAt        = TimeCodec::fromDb(record.value(QStringLiteral("last_login_at")));
    user.createdAt          = TimeCodec::fromDb(record.value(QStringLiteral("created_at")));
    user.updatedAt          = TimeCodec::fromDb(record.value(QStringLiteral("updated_at")));
    return user;
}

QList<UserAccount> UserAccountDao::loadAll()
{
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("SELECT * FROM user_account ORDER BY username COLLATE NOCASE"))) {
        qWarning() << "UserAccountDao::loadAll:" << query.lastError().text();
        return {};
    }

    QList<UserAccount> users;
    while (query.next())
        users.append(rowToUser(query.record()));
    return users;
}

std::optional<UserAccount> UserAccountDao::findById(int id) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("SELECT * FROM user_account WHERE id = :id"));
    query.bindValue(QStringLiteral(":id"), id);
    if (!query.exec()) {
        qWarning() << "UserAccountDao::findById:" << query.lastError().text();
        return std::nullopt;
    }
    if (!query.next())
        return std::nullopt;
    return rowToUser(query.record());
}

std::optional<UserAccount> UserAccountDao::findByUsername(const QString &username) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral("SELECT * FROM user_account WHERE username = :username"));
    query.bindValue(QStringLiteral(":username"), username.trimmed());
    if (!query.exec()) {
        qWarning() << "UserAccountDao::findByUsername:" << query.lastError().text();
        return std::nullopt;
    }
    if (!query.next())
        return std::nullopt;
    return rowToUser(query.record());
}

bool UserAccountDao::insert(UserAccount &user)
{
    user.username = user.username.trimmed();
    if (user.username.isEmpty() || user.passwordHash.isEmpty() || !isKnownUserRole(userRoleToString(user.role))) {
        qWarning() << "UserAccountDao::insert: username/password_hash/role không hợp lệ";
        return false;
    }
    if (user.displayName.trimmed().isEmpty())
        user.displayName = user.username;

    const QDateTime now = QDateTime::currentDateTimeUtc();
    if (!user.createdAt.isValid())
        user.createdAt = now;
    user.updatedAt = now;

    QSqlQuery query(m_db);
    query.prepare(R"(
        INSERT INTO user_account
            (username, display_name, role, password_hash, active, must_change_password,
             failed_attempts, locked_until, last_login_at, created_at, updated_at)
        VALUES
            (:username, :display_name, :role, :password_hash, :active, :must_change,
             :failed_attempts, :locked_until, :last_login_at, :created_at, :updated_at))");
    query.bindValue(QStringLiteral(":username"), user.username);
    query.bindValue(QStringLiteral(":display_name"), user.displayName);
    query.bindValue(QStringLiteral(":role"), userRoleToString(user.role));
    query.bindValue(QStringLiteral(":password_hash"), user.passwordHash);
    query.bindValue(QStringLiteral(":active"), user.active ? 1 : 0);
    query.bindValue(QStringLiteral(":must_change"), user.mustChangePassword ? 1 : 0);
    query.bindValue(QStringLiteral(":failed_attempts"), user.failedAttempts);
    query.bindValue(QStringLiteral(":locked_until"), TimeCodec::toDbOrNull(user.lockedUntil));
    query.bindValue(QStringLiteral(":last_login_at"), TimeCodec::toDbOrNull(user.lastLoginAt));
    query.bindValue(QStringLiteral(":created_at"), TimeCodec::toDb(user.createdAt));
    query.bindValue(QStringLiteral(":updated_at"), TimeCodec::toDb(user.updatedAt));

    if (!query.exec()) {
        qWarning() << "UserAccountDao::insert:" << query.lastError().text();
        return false;
    }

    user.id = query.lastInsertId().toInt();
    return user.id > 0;
}

bool UserAccountDao::update(const UserAccount &user)
{
    if (user.id <= 0 || user.username.trimmed().isEmpty()
        || user.passwordHash.isEmpty() || !isKnownUserRole(userRoleToString(user.role))) {
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(
        UPDATE user_account SET
            display_name = :display_name,
            role = :role,
            password_hash = :password_hash,
            active = :active,
            must_change_password = :must_change,
            failed_attempts = :failed_attempts,
            locked_until = :locked_until,
            updated_at = :updated_at
        WHERE id = :id)");
    query.bindValue(QStringLiteral(":display_name"), user.displayName.trimmed().isEmpty()
                                                      ? user.username : user.displayName);
    query.bindValue(QStringLiteral(":role"), userRoleToString(user.role));
    query.bindValue(QStringLiteral(":password_hash"), user.passwordHash);
    query.bindValue(QStringLiteral(":active"), user.active ? 1 : 0);
    query.bindValue(QStringLiteral(":must_change"), user.mustChangePassword ? 1 : 0);
    query.bindValue(QStringLiteral(":failed_attempts"), user.failedAttempts);
    query.bindValue(QStringLiteral(":locked_until"), TimeCodec::toDbOrNull(user.lockedUntil));
    query.bindValue(QStringLiteral(":updated_at"), TimeCodec::toDb(QDateTime::currentDateTimeUtc()));
    query.bindValue(QStringLiteral(":id"), user.id);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::update:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool UserAccountDao::updatePasswordHash(int id, const QString &hash, bool mustChangePassword)
{
    if (id <= 0 || hash.isEmpty())
        return false;

    QSqlQuery query(m_db);
    query.prepare(R"(
        UPDATE user_account SET
            password_hash = :hash,
            must_change_password = :must_change,
            failed_attempts = 0,
            locked_until = NULL,
            updated_at = :updated_at
        WHERE id = :id)");
    query.bindValue(QStringLiteral(":hash"), hash);
    query.bindValue(QStringLiteral(":must_change"), mustChangePassword ? 1 : 0);
    query.bindValue(QStringLiteral(":updated_at"), TimeCodec::toDb(QDateTime::currentDateTimeUtc()));
    query.bindValue(QStringLiteral(":id"), id);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::updatePasswordHash:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool UserAccountDao::setActive(int id, bool active)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE user_account SET active = :active, updated_at = :updated_at WHERE id = :id"));
    query.bindValue(QStringLiteral(":active"), active ? 1 : 0);
    query.bindValue(QStringLiteral(":updated_at"), TimeCodec::toDb(QDateTime::currentDateTimeUtc()));
    query.bindValue(QStringLiteral(":id"), id);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::setActive:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool UserAccountDao::updateLoginState(int id, int failedAttempts,
                                      const QDateTime &lockedUntil)
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE user_account SET failed_attempts = :failed, locked_until = :locked, "
        "updated_at = :updated_at WHERE id = :id"));
    query.bindValue(QStringLiteral(":failed"), qMax(0, failedAttempts));
    query.bindValue(QStringLiteral(":locked"), TimeCodec::toDbOrNull(lockedUntil));
    query.bindValue(QStringLiteral(":updated_at"), TimeCodec::toDb(QDateTime::currentDateTimeUtc()));
    query.bindValue(QStringLiteral(":id"), id);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::updateLoginState:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool UserAccountDao::recordLoginSuccess(int id)
{
    const QString now = TimeCodec::toDb(QDateTime::currentDateTimeUtc());

    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "UPDATE user_account SET failed_attempts = 0, locked_until = NULL, "
        "last_login_at = :now, updated_at = :now WHERE id = :id"));
    query.bindValue(QStringLiteral(":now"), now);
    query.bindValue(QStringLiteral(":id"), id);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::recordLoginSuccess:" << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

int UserAccountDao::countActiveAdmins() const
{
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral(
            "SELECT COUNT(*) FROM user_account WHERE role = 'admin' AND active = 1"))) {
        qWarning() << "UserAccountDao::countActiveAdmins:" << query.lastError().text();
        return 0;
    }
    return query.next() ? query.value(0).toInt() : 0;
}

bool UserAccountDao::usernameExists(const QString &username, int excludeId) const
{
    QSqlQuery query(m_db);
    query.prepare(QStringLiteral(
        "SELECT 1 FROM user_account WHERE username = :username AND id != :exclude LIMIT 1"));
    query.bindValue(QStringLiteral(":username"), username.trimmed());
    query.bindValue(QStringLiteral(":exclude"), excludeId);

    if (!query.exec()) {
        qWarning() << "UserAccountDao::usernameExists:" << query.lastError().text();
        return false;
    }
    return query.next();
}
