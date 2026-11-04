#include "KioskAccessController.h"

#include "AuthService.h"

KioskAccessController::KioskAccessController(QObject *parent)
    : QObject(parent), m_auth(AuthService::instance())
{
    if (m_auth) {
        connect(m_auth, &AuthService::sessionChanged,
                this, &KioskAccessController::onSessionChanged);
        connect(m_auth, &QObject::destroyed, this, [this]() { onSessionChanged(); });
    }
}

bool KioskAccessController::isAllowed(int target) const
{
    if (target >= Monitor && target <= Trending)
        return true;
    if (!m_auth)
        return false;
    if (target == Settings)
        return m_auth->canConfigureSensors();
    if (target == Tester)
        return m_auth->canRunTester();
    if (target == Calibration)
        return m_auth->canCalibrate();
    return false;
}

void KioskAccessController::setCurrentTab(int tab)
{
    if (m_currentTab == tab)
        return;
    m_currentTab = tab;
    emit currentTabChanged();
}

void KioskAccessController::setPendingTarget(int target)
{
    const bool wasRequested = authenticationRequested();
    m_pendingTarget = target;
    if (wasRequested != authenticationRequested())
        emit authenticationRequestedChanged();
}

void KioskAccessController::completeRequest(int target)
{
    setPendingTarget(-1);
    if (target <= Tester)
        setCurrentTab(target);
    emit actionAuthorized(target);
}

bool KioskAccessController::request(int target)
{
    if (target < Monitor || target > Calibration)
        return false;
    if (!isAllowed(target)) {
        setPendingTarget(target);
        return false;
    }
    completeRequest(target);
    return true;
}

void KioskAccessController::cancelAuthentication()
{
    setPendingTarget(-1);
}

void KioskAccessController::onSessionChanged()
{
    // Hết quyền trong Settings/Tester thì quay về giám sát, không hiện login.
    if (!isAllowed(m_currentTab))
        setCurrentTab(Monitor);
    if (m_pendingTarget >= 0 && isAllowed(m_pendingTarget))
        completeRequest(m_pendingTarget);
}
