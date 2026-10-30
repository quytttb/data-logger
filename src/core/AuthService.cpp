#include "AuthService.h"

#include "data/db/Database.h"
#include "data/db/TimeCodec.h"
#include "data/repositories/UserAccountDao.h"
#include "utils/security/PasswordHasher.h"

#include <QEvent>
#include <QGuiApplication>
#include <QtConcurrent/QtConcurrentRun>
#include <QtDebug>

IMPLEMENT_QML_SINGLETON(AuthService)

namespace {

constexpr int kLockBaseSeconds = 60;
constexpr int kLockMaxSeconds = 900;

// 5 lần sai -> 60s; 10 -> 120s; 15 -> 240s; ... tối đa 15 phút.
int lockSecondsFor(int failedAttempts)
{
    if (failedAttempts < AuthService::kMaxFailedAttemptsBeforeLock)
        return 0;
    const int steps = (failedAttempts / AuthService::kMaxFailedAttemptsBeforeLock) - 1;
    int seconds = kLockBaseSeconds;
    for (int i = 0; i < steps && seconds < kLockMaxSeconds; ++i)
        seconds *= 2;
    return qMin(seconds, kLockMaxSeconds);
}

QString remainingLockText(const QDateTime &until)
{
    const qint64 seconds = QDateTime::currentDateTimeUtc().secsTo(until);
    if (seconds <= 0)
        return {};
    if (seconds < 60)
        return QStringLiteral("%1 seconds").arg(seconds);
    return QStringLiteral("%1 minutes").arg((seconds + 59) / 60);
}

QString attemptText(int attempts)
{
    return QStringLiteral("%1 attempt(s) left.")
        .arg(qMax(0, AuthService::kMaxFailedAttemptsBeforeLock - attempts));
}

} // namespace

AuthService::AuthService(QObject *parent) : QObject(parent)
{
    m_idleTimer.setSingleShot(true);
    m_idleTimer.setInterval(kIdleTimeoutMinutes * 60 * 1000);
    connect(&m_idleTimer, &QTimer::timeout, this, &AuthService::lock);

    updateUserCount();
    if (qApp)
        qApp->installEventFilter(this);
}

AuthService::~AuthService()
{
    if (qApp)
        qApp->removeEventFilter(this);
}

QString AuthService::validatePassword(const QString &username, const QString &password)
{
    if (password.size() < 8)
        return QStringLiteral("Password must be at least 8 characters.");
    if (password.size() > 128)
        return QStringLiteral("Password must be at most 128 characters.");

    bool hasLetter = false;
    bool hasDigit = false;
    for (const QChar ch : password) {
        if (ch.isLetter())
            hasLetter = true;
        else if (ch.isDigit())
            hasDigit = true;
    }
    if (!hasLetter || !hasDigit)
        return QStringLiteral("Password must contain at least one letter and one digit.");

    const QString name = username.trimmed();
    if (!name.isEmpty() && password.compare(name, Qt::CaseInsensitive) == 0)
        return QStringLiteral("Password must not be the same as the username.");
    return {};
}

QString AuthService::passwordPolicyError(const QString &username, const QString &password) const
{
    return validatePassword(username, password);
}

bool AuthService::can(Permission permission) const
{
    if (!m_authenticated || m_locked)
        return false;

    // Tài khoản vừa được admin tạo/reset phải đổi mật khẩu trước khi làm gì khác.
    if (m_currentUser.mustChangePassword && permission != Permission::ViewData)
        return false;

    switch (m_currentUser.role) {
    case UserRole::Admin:
        return true;
    case UserRole::Operator:
        return permission == Permission::ViewData
            || permission == Permission::RunTester
            || permission == Permission::Calibrate;
    case UserRole::Viewer:
        return permission == Permission::ViewData;
    }
    return false;
}

bool AuthService::authorize(Permission permission)
{
    AuthService *service = instance();
    return service && service->can(permission);
}

void AuthService::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void AuthService::updateUserCount()
{
    int count = 0;
    {
        ScopedDbConnection db;
        UserAccountDao dao(db);
        count = qMax(0, dao.count());
    }

    if (m_userCount != count) {
        m_userCount = count;
        emit usersChanged();
    }

    const bool firstRun = m_userCount == 0;
    if (m_firstRun != firstRun) {
        m_firstRun = firstRun;
        emit firstRunChanged();
    }
}

void AuthService::refreshUsers()
{
    updateUserCount();
    emit usersChanged();
}

QVariantList AuthService::users()
{
    QVariantList out;
    if (!canManageUsers())
        return out;

    ScopedDbConnection db;
    UserAccountDao dao(db);
    for (const UserAccount &user : dao.loadAll()) {
        out.append(QVariantMap {
            {QStringLiteral("id"), user.id},
            {QStringLiteral("username"), user.username},
            {QStringLiteral("displayName"), user.displayName},
            {QStringLiteral("role"), userRoleToString(user.role)},
            {QStringLiteral("active"), user.active},
            {QStringLiteral("mustChangePassword"), user.mustChangePassword},
            {QStringLiteral("lastLoginAt"), user.lastLoginAt.isValid()
                     ? TimeCodec::toDb(user.lastLoginAt) : QString()},
            {QStringLiteral("lockedUntil"), user.lockedUntil.isValid()
                     ? TimeCodec::toDb(user.lockedUntil) : QString()},
        });
    }
    return out;
}

void AuthService::startSession(const UserAccount &user)
{
    m_currentUser = user;
    m_authenticated = true;
    m_locked = false;
    startIdleTimer();
    emit sessionChanged();
}

void AuthService::endSession()
{
    m_currentUser = {};
    m_authenticated = false;
    m_locked = false;
    m_idleTimer.stop();
    emit sessionChanged();
}

void AuthService::startIdleTimer()
{
    if (m_authenticated && !m_locked)
        m_idleTimer.start();
}

void AuthService::notifyActivity()
{
    if (m_authenticated && !m_locked && !m_busy)
        m_idleTimer.start();
}

bool AuthService::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::KeyPress:
    case QEvent::TouchBegin:
    case QEvent::Wheel:
        notifyActivity();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void AuthService::lock()
{
    if (!m_authenticated || m_locked)
        return;
    m_locked = true;
    m_idleTimer.stop();
    emit sessionChanged();
}

void AuthService::logout()
{
    endSession();
}

void AuthService::runTask(std::function<TaskResult()> work)
{
    if (m_busy) {
        emit messageSent(QStringLiteral("Please wait"),
                         QStringLiteral("Another security operation is in progress."));
        return;
    }

    setBusy(true);
    QPointer<AuthService> self(this);
    QtConcurrent::run([self, work = std::move(work)]() {
        const TaskResult result = work();
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, result]() {
            if (self)
                self->finishTask(result);
        }, Qt::QueuedConnection);
    });
}

void AuthService::finishTask(const TaskResult &result)
{
    setBusy(false);

    if (!result.ok) {
        emit messageSent(result.errorTitle.isEmpty()
                             ? QStringLiteral("Error") : result.errorTitle,
                         result.error.isEmpty()
                             ? QStringLiteral("Operation failed.") : result.error);
        return;
    }

    switch (result.kind) {
    case TaskResult::Kind::Login:
        startSession(result.user);
        break;
    case TaskResult::Kind::CreateFirstAdmin:
        updateUserCount();
        startSession(result.user);
        break;
    case TaskResult::Kind::Unlock:
        m_currentUser = result.user;
        m_locked = false;
        startIdleTimer();
        emit sessionChanged();
        break;
    case TaskResult::Kind::ChangePassword:
        m_currentUser.mustChangePassword = false;
        emit sessionChanged();
        emit usersChanged();
        break;
    case TaskResult::Kind::CreateUser:
        updateUserCount();
        emit usersChanged();
        break;
    case TaskResult::Kind::ResetPassword:
        emit usersChanged();
        break;
    }

    if (!result.success.isEmpty())
        emit messageSent(QStringLiteral("Success"), result.success);
}

void AuthService::login(const QString &username, const QString &password)
{
    const QString name = username.trimmed();
    if (name.isEmpty() || password.isEmpty()) {
        emit messageSent(QStringLiteral("Sign in"),
                         QStringLiteral("Enter username and password."));
        return;
    }
    if (m_authenticated) {
        emit messageSent(QStringLiteral("Sign in"),
                         QStringLiteral("Please sign out before signing in again."));
        return;
    }

    runTask([name, password]() {
        TaskResult result;
        result.kind = TaskResult::Kind::Login;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        auto user = dao.findByUsername(name);
        if (!user) {
            result.error = QStringLiteral("Wrong username or password.");
            return result;
        }
        if (!user->active) {
            result.error = QStringLiteral("This account is disabled.");
            return result;
        }

        const QDateTime now = QDateTime::currentDateTimeUtc();
        if (user->lockedUntil.isValid() && user->lockedUntil > now) {
            result.error = QStringLiteral("Too many failed attempts. Try again in %1.")
                               .arg(remainingLockText(user->lockedUntil));
            return result;
        }

        bool needsRehash = false;
        if (!PasswordHasher::verify(password, user->passwordHash, &needsRehash)) {
            const int attempts = user->failedAttempts + 1;
            const int lockSeconds = lockSecondsFor(attempts);
            QDateTime lockedUntil;
            if (lockSeconds > 0)
                lockedUntil = now.addSecs(lockSeconds);
            dao.updateLoginState(user->id, attempts, lockedUntil);

            if (lockSeconds > 0) {
                result.error = QStringLiteral("Wrong password. Account locked for %1 seconds.")
                                   .arg(lockSeconds);
            } else {
                result.error = QStringLiteral("Wrong username or password. %1")
                                   .arg(attemptText(attempts));
            }
            return result;
        }

        if (needsRehash)
            dao.updatePasswordHash(user->id, PasswordHasher::hash(password),
                                   user->mustChangePassword);
        dao.recordLoginSuccess(user->id);

        user->failedAttempts = 0;
        user->lockedUntil = {};
        user->lastLoginAt = now;
        result.ok = true;
        result.user = *user;
        result.success = QStringLiteral("Signed in.");
        return result;
    });
}

void AuthService::unlock(const QString &password)
{
    if (!m_authenticated || !m_locked)
        return;
    if (password.isEmpty()) {
        emit messageSent(QStringLiteral("Unlock"), QStringLiteral("Enter your password."));
        return;
    }

    runTask([id = m_currentUser.id, password]() {
        TaskResult result;
        result.kind = TaskResult::Kind::Unlock;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        auto user = dao.findById(id);
        if (!user) {
            result.error = QStringLiteral("Session expired. Sign in again.");
            return result;
        }
        if (!user->active) {
            result.error = QStringLiteral("This account is disabled.");
            return result;
        }

        const QDateTime now = QDateTime::currentDateTimeUtc();
        if (user->lockedUntil.isValid() && user->lockedUntil > now) {
            result.error = QStringLiteral("Too many failed attempts. Try again in %1.")
                               .arg(remainingLockText(user->lockedUntil));
            return result;
        }

        if (!PasswordHasher::verify(password, user->passwordHash)) {
            const int attempts = user->failedAttempts + 1;
            const int lockSeconds = lockSecondsFor(attempts);
            dao.updateLoginState(user->id, attempts,
                                 lockSeconds > 0 ? now.addSecs(lockSeconds) : QDateTime());
            result.error = lockSeconds > 0
                ? QStringLiteral("Wrong password. Account locked for %1 seconds.").arg(lockSeconds)
                : QStringLiteral("Wrong password. %1").arg(attemptText(attempts));
            return result;
        }

        dao.recordLoginSuccess(user->id);
        user->failedAttempts = 0;
        user->lockedUntil = {};
        result.ok = true;
        result.user = *user;
        return result;
    });
}

void AuthService::createFirstAdmin(const QString &username, const QString &displayName,
                                   const QString &password, const QString &confirm)
{
    if (m_busy)
        return;
    if (!m_firstRun) {
        emit messageSent(QStringLiteral("Setup"),
                         QStringLiteral("An administrator account already exists."));
        return;
    }

    const QString name = username.trimmed();
    if (name.isEmpty()) {
        emit messageSent(QStringLiteral("Setup"), QStringLiteral("Enter a username."));
        return;
    }
    if (password != confirm) {
        emit messageSent(QStringLiteral("Setup"), QStringLiteral("Passwords do not match."));
        return;
    }
    const QString policyError = validatePassword(name, password);
    if (!policyError.isEmpty()) {
        emit messageSent(QStringLiteral("Setup"), policyError);
        return;
    }

    runTask([name, displayName, password]() {
        TaskResult result;
        result.kind = TaskResult::Kind::CreateFirstAdmin;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        if (dao.count() > 0) {
            result.error = QStringLiteral("An administrator account already exists.");
            return result;
        }

        UserAccount admin;
        admin.username = name;
        admin.displayName = displayName.trimmed().isEmpty() ? name : displayName.trimmed();
        admin.role = UserRole::Admin;
        admin.active = true;
        admin.passwordHash = PasswordHasher::hash(password);
        if (!dao.insert(admin)) {
            result.error = QStringLiteral("Could not create the administrator account.");
            return result;
        }

        result.ok = true;
        result.user = admin;
        result.success = QStringLiteral("Administrator account created.");
        return result;
    });
}

void AuthService::changePassword(const QString &oldPassword, const QString &newPassword,
                                 const QString &confirm)
{
    if (!m_authenticated)
        return;
    if (newPassword != confirm) {
        emit messageSent(QStringLiteral("Change password"), QStringLiteral("Passwords do not match."));
        return;
    }
    const QString policyError = validatePassword(m_currentUser.username, newPassword);
    if (!policyError.isEmpty()) {
        emit messageSent(QStringLiteral("Change password"), policyError);
        return;
    }

    runTask([id = m_currentUser.id, oldPassword, newPassword]() {
        TaskResult result;
        result.kind = TaskResult::Kind::ChangePassword;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        auto user = dao.findById(id);
        if (!user) {
            result.error = QStringLiteral("Account not found.");
            return result;
        }
        if (!PasswordHasher::verify(oldPassword, user->passwordHash)) {
            result.error = QStringLiteral("Current password is wrong.");
            return result;
        }

        const QString hash = PasswordHasher::hash(newPassword);
        if (hash.isEmpty() || !dao.updatePasswordHash(user->id, hash, false)) {
            result.error = QStringLiteral("Could not change the password.");
            return result;
        }

        result.ok = true;
        result.success = QStringLiteral("Password changed.");
        return result;
    });
}

void AuthService::createUser(const QString &username, const QString &displayName,
                             const QString &role, const QString &password,
                             const QString &confirm)
{
    if (!authorize(Permission::ManageUsers)) {
        emit messageSent(QStringLiteral("Permission denied"),
                         QStringLiteral("Only administrators can manage accounts."));
        return;
    }
    if (!isKnownUserRole(role)) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Invalid role."));
        return;
    }
    const QString name = username.trimmed();
    if (name.isEmpty()) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Enter a username."));
        return;
    }
    if (password != confirm) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Passwords do not match."));
        return;
    }
    const QString policyError = validatePassword(name, password);
    if (!policyError.isEmpty()) {
        emit messageSent(QStringLiteral("Accounts"), policyError);
        return;
    }

    runTask([name, displayName, role, password]() {
        TaskResult result;
        result.kind = TaskResult::Kind::CreateUser;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        if (dao.findByUsername(name).has_value()) {
            result.error = QStringLiteral("That username is already taken.");
            return result;
        }

        UserAccount user;
        user.username = name;
        user.displayName = displayName.trimmed().isEmpty() ? name : displayName.trimmed();
        user.role = userRoleFromString(role);
        user.active = true;
        user.mustChangePassword = true;
        user.passwordHash = PasswordHasher::hash(password);
        if (!dao.insert(user)) {
            result.error = QStringLiteral("Could not create the account.");
            return result;
        }

        result.ok = true;
        result.success = QStringLiteral("Account created. The user must change the password "
                                        "at first sign-in.");
        return result;
    });
}

void AuthService::resetPassword(int userId, const QString &newPassword, const QString &confirm)
{
    if (!authorize(Permission::ManageUsers)) {
        emit messageSent(QStringLiteral("Permission denied"),
                         QStringLiteral("Only administrators can reset passwords."));
        return;
    }
    if (userId == m_currentUser.id) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("Use Change password for your own account."));
        return;
    }
    if (newPassword != confirm) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Passwords do not match."));
        return;
    }

    runTask([userId, newPassword]() {
        TaskResult result;
        result.kind = TaskResult::Kind::ResetPassword;

        ScopedDbConnection db;
        UserAccountDao dao(db);
        auto user = dao.findById(userId);
        if (!user) {
            result.error = QStringLiteral("Account not found.");
            return result;
        }
        const QString policyError = validatePassword(user->username, newPassword);
        if (!policyError.isEmpty()) {
            result.error = policyError;
            return result;
        }

        const QString hash = PasswordHasher::hash(newPassword);
        if (hash.isEmpty() || !dao.updatePasswordHash(userId, hash, true)) {
            result.error = QStringLiteral("Could not reset the password.");
            return result;
        }

        result.ok = true;
        result.success = QStringLiteral("Password reset. The user must change it at next sign-in.");
        return result;
    });
}

bool AuthService::setUserActive(int userId, bool active)
{
    if (!authorize(Permission::ManageUsers)) {
        emit messageSent(QStringLiteral("Permission denied"),
                         QStringLiteral("Only administrators can manage accounts."));
        return false;
    }
    if (userId == m_currentUser.id && !active) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("You cannot disable your own account."));
        return false;
    }

    ScopedDbConnection db;
    UserAccountDao dao(db);
    auto target = dao.findById(userId);
    if (!target) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Account not found."));
        return false;
    }
    if (!active && target->role == UserRole::Admin && target->active
        && dao.countActiveAdmins() <= 1) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("Cannot disable the last administrator."));
        return false;
    }
    if (!dao.setActive(userId, active)) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("Could not update the account."));
        return false;
    }

    emit usersChanged();
    return true;
}

bool AuthService::setUserRole(int userId, const QString &role)
{
    if (!authorize(Permission::ManageUsers)) {
        emit messageSent(QStringLiteral("Permission denied"),
                         QStringLiteral("Only administrators can manage accounts."));
        return false;
    }
    if (!isKnownUserRole(role)) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Invalid role."));
        return false;
    }
    if (userId == m_currentUser.id) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("You cannot change your own role."));
        return false;
    }

    const UserRole newRole = userRoleFromString(role);
    ScopedDbConnection db;
    UserAccountDao dao(db);
    auto target = dao.findById(userId);
    if (!target) {
        emit messageSent(QStringLiteral("Accounts"), QStringLiteral("Account not found."));
        return false;
    }
    if (target->role == UserRole::Admin && target->active && newRole != UserRole::Admin
        && dao.countActiveAdmins() <= 1) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("Cannot demote the last administrator."));
        return false;
    }
    if (!dao.setRole(userId, newRole)) {
        emit messageSent(QStringLiteral("Accounts"),
                         QStringLiteral("Could not update the role."));
        return false;
    }

    emit usersChanged();
    return true;
}
