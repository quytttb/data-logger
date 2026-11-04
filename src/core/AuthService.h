#pragma once
#include "data/models/UserAccount.h"
#include "utils/qml/QmlSingleton.h"

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

#include <functional>

// Quyền theo thao tác thực tế. Không dùng role trực tiếp ở write path để sau
// này có thể thêm quyền mà không phải sửa từng controller.
enum class Permission {
    ViewData,
    RunTester,
    Calibrate,
    ConfigureSensors,
    ConfigureSystem,
    ManageUsers,
    ViewAudit,
};

// Phiên đăng nhập cục bộ trên kiosk.
//
// - Mật khẩu băm PBKDF2 nằm trong DB; service chỉ giữ bản sao tài khoản trong
//   RAM (không lưu mật khẩu).
// - Băm/xác thực chạy trên thread pool (QtConcurrent) để không chặn UI khi
//   PBKDF2 600k vòng trên Pi 3.
// - Tự khóa sau 5 phút không có thao tác; đăng nhập sai 5 lần liên tiếp sẽ
//   khóa tạm thời, thời gian khóa tăng dần.
// - Danh tính ở đây là người dùng kiosk, KHÔNG phải token thiết bị của REST.
class AuthService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool authenticated READ authenticated NOTIFY sessionChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY sessionChanged)
    Q_PROPERTY(bool firstRun READ firstRun NOTIFY firstRunChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int userCount READ userCount NOTIFY usersChanged)
    Q_PROPERTY(QString currentUsername READ currentUsername NOTIFY sessionChanged)
    Q_PROPERTY(QString currentDisplayName READ currentDisplayName NOTIFY sessionChanged)
    Q_PROPERTY(QString currentRole READ currentRole NOTIFY sessionChanged)
    Q_PROPERTY(bool mustChangePassword READ mustChangePassword NOTIFY sessionChanged)

    // Quyền dùng cho binding QML (ẩn/disable nút). Backend vẫn kiểm tra lại
    // tại điểm thực thi — không tin QML.
    Q_PROPERTY(bool canViewData READ canViewData NOTIFY sessionChanged)
    Q_PROPERTY(bool canRunTester READ canRunTester NOTIFY sessionChanged)
    Q_PROPERTY(bool canCalibrate READ canCalibrate NOTIFY sessionChanged)
    Q_PROPERTY(bool canConfigureSensors READ canConfigureSensors NOTIFY sessionChanged)
    Q_PROPERTY(bool canConfigureSystem READ canConfigureSystem NOTIFY sessionChanged)
    Q_PROPERTY(bool canManageUsers READ canManageUsers NOTIFY sessionChanged)
    Q_PROPERTY(bool canViewAudit READ canViewAudit NOTIFY sessionChanged)

public:
    explicit AuthService(QObject *parent = nullptr);
    ~AuthService() override;

    DECLARE_QML_SINGLETON(AuthService)

    static constexpr int kIdleTimeoutMinutes = 5;
    static constexpr int kMaxFailedAttemptsBeforeLock = 5;

    bool authenticated() const { return m_authenticated; }
    bool locked() const { return m_locked; }
    bool firstRun() const { return m_firstRun; }
    bool busy() const { return m_busy; }
    int userCount() const { return m_userCount; }
    int currentUserId() const { return m_currentUser.id; }
    QString currentUsername() const { return m_currentUser.username; }
    QString currentDisplayName() const { return m_currentUser.displayName; }
    QString currentRole() const { return userRoleToString(m_currentUser.role); }
    bool mustChangePassword() const { return m_currentUser.mustChangePassword; }

    bool canViewData() const { return can(Permission::ViewData); }
    bool canRunTester() const { return can(Permission::RunTester); }
    bool canCalibrate() const { return can(Permission::Calibrate); }
    bool canConfigureSensors() const { return can(Permission::ConfigureSensors); }
    bool canConfigureSystem() const { return can(Permission::ConfigureSystem); }
    bool canManageUsers() const { return can(Permission::ManageUsers); }
    bool canViewAudit() const { return can(Permission::ViewAudit); }

    bool can(Permission permission) const;

    // Kiểm tra quyền tại điểm thực thi (controller). Fail-closed nếu chưa có
    // instance — mọi write path trong app đều chạy sau khi main tạo service.
    static bool authorize(Permission permission);

    // Chính sách mật khẩu dùng chung cho UI và backend.
    Q_INVOKABLE QString passwordPolicyError(const QString &username,
                                            const QString &password) const;
    static QString validatePassword(const QString &username, const QString &password);

    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void unlock(const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void lock();

    // Lần chạy đầu tiên: tạo admin duy nhất khi DB chưa có tài khoản.
    Q_INVOKABLE void createFirstAdmin(const QString &username, const QString &displayName,
                                      const QString &password, const QString &confirm);
    Q_INVOKABLE void changePassword(const QString &oldPassword, const QString &newPassword,
                                    const QString &confirm);
    Q_INVOKABLE void createUser(const QString &username, const QString &displayName,
                                const QString &role, const QString &password,
                                const QString &confirm);
    Q_INVOKABLE void resetPassword(int userId, const QString &newPassword,
                                   const QString &confirm);
    Q_INVOKABLE bool setUserActive(int userId, bool active);
    Q_INVOKABLE bool setUserRole(int userId, const QString &role);
    Q_INVOKABLE bool updateUser(int userId, const QString &displayName,
                                const QString &role, bool active);
    Q_INVOKABLE bool deleteUser(int userId);
    Q_INVOKABLE QVariantList users();
    Q_INVOKABLE void refreshUsers();

    // Gọi khi có thao tác người dùng (event filter toàn cục tự làm việc này).
    Q_INVOKABLE void notifyActivity();

signals:
    void sessionChanged();
    void firstRunChanged();
    void busyChanged();
    void usersChanged();
    void messageSent(QString title, QString body);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    struct TaskResult {
        enum class Kind {
            Login,
            CreateFirstAdmin,
            Unlock,
            ChangePassword,
            CreateUser,
            ResetPassword,
        } kind = Kind::Login;
        bool ok = false;
        QString errorTitle;
        QString error;
        QString success;
        UserAccount user;
    };

    void runTask(std::function<TaskResult()> work);
    void finishTask(const TaskResult &result);
    void startSession(const UserAccount &user);
    void endSession();
    void setBusy(bool busy);
    void startIdleTimer();
    void updateUserCount();

    QTimer m_idleTimer;
    UserAccount m_currentUser;
    bool m_authenticated = false;
    bool m_locked = false;
    bool m_firstRun = false;
    bool m_busy = false;
    int m_userCount = 0;
};

// Qt ưu tiên constructor mặc định hơn create() khi đăng ký singleton trực
// tiếp. Dùng wrapper để QML và backend luôn dùng cùng phiên do main tạo.
struct AuthServiceQml {
    Q_GADGET
    QML_FOREIGN(AuthService)
    QML_NAMED_ELEMENT(AuthService)
    QML_SINGLETON

public:
    static AuthService *create(QQmlEngine *engine, QJSEngine *jsEngine)
    {
        return AuthService::create(engine, jsEngine);
    }
};
