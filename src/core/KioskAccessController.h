#pragma once

#include <QObject>
#include <QPointer>
#include <QtQmlIntegration/qqmlintegration.h>

class AuthService;

// Điều hướng kiosk: xem dữ liệu luôn mở, chỉ yêu cầu phiên cho thao tác ghi.
class KioskAccessController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int currentTab READ currentTab NOTIFY currentTabChanged)
    Q_PROPERTY(bool authenticationRequested READ authenticationRequested
               NOTIFY authenticationRequestedChanged)

public:
    enum Target { Monitor = 0, History = 1, Trending = 2, Settings = 3,
                  Tester = 4, Calibration = 5 };
    Q_ENUM(Target)

    explicit KioskAccessController(QObject *parent = nullptr);

    int currentTab() const { return m_currentTab; }
    bool authenticationRequested() const { return m_pendingTarget >= 0; }

    Q_INVOKABLE bool request(int target);
    Q_INVOKABLE void cancelAuthentication();

signals:
    void currentTabChanged();
    void authenticationRequestedChanged();
    void actionAuthorized(int target);

private:
    bool isAllowed(int target) const;
    void setCurrentTab(int tab);
    void setPendingTarget(int target);
    void completeRequest(int target);
    void onSessionChanged();

    QPointer<AuthService> m_auth;
    int m_currentTab = Monitor;
    int m_pendingTarget = -1;
};
