#include "SettingsController.h"
#include "AuditTrail.h"
#include "AuthService.h"
#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "utils/crypto/Crypto.h"
#include "utils/network/LanIp.h"
#include "utils/provision/ProvisionQr.h"
#include "utils/system/AppDefaults.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QProcess>
#include <QDebug>

IMPLEMENT_QML_SINGLETON(SettingsController)

namespace {
const QString kDefaultTheme    = AppDefaults::theme;
const QString kBindAnyIPv4     = AppDefaults::bindAnyIPv4;
const QString kBindAnyIPv6     = QStringLiteral("::");
const QString kProvisionSchema = QStringLiteral("central-logger-provision/v1");

// Lưu app_config + ghi audit trong cùng transaction: nếu audit lỗi thì cấu
// hình rollback, không báo thành công khi thiếu dấu vết.
bool saveConfigWithAudit(AppConfigDao &dao, QSqlDatabase &db, const AppConfig &cfg,
                         const QString &action, const QJsonObject &detail)
{
    if (!db.transaction())
        return false;

    bool ok = dao.save(cfg);
    if (ok) {
        AuditLogEntry entry = AuditTrail::entry(
            AuditTrail::localActor(), action, QStringLiteral("app_config"),
            QString::number(cfg.id), AuditResult::Ok, detail);
        ok = AuditTrail::append(db, entry);
    }
    if (ok)
        ok = db.commit();
    if (!ok)
        db.rollback();
    return ok;
}
}

SettingsController::SettingsController(QObject *parent) : QObject(parent) {}

QJsonObject SettingsController::auditChanges(const AppConfig &before, const AppConfig &after)
{
    // Whitelist trường cần truy vết. KHÔNG đưa ftpPassword / restApiToken vào
    // đây — audit chỉ lưu tên trường và giá trị không nhạy cảm.
    return AuditTrail::changes({
        {QStringLiteral("stationCode"), before.stationCode, after.stationCode},
        {QStringLiteral("stationName"), before.stationName, after.stationName},
        {QStringLiteral("timeFormat"), before.timeFormat, after.timeFormat},
        {QStringLiteral("dateFormat"), before.dateFormat, after.dateFormat},
        {QStringLiteral("timezone"), before.timezone, after.timezone},
        {QStringLiteral("buzzerEnable"), before.buzzerEnable, after.buzzerEnable},
        {QStringLiteral("ftpAddress"), before.ftpAddress, after.ftpAddress},
        {QStringLiteral("ftpPort"), before.ftpPort, after.ftpPort},
        {QStringLiteral("ftpUsername"), before.ftpUsername, after.ftpUsername},
        {QStringLiteral("ftpRemotePath"), before.ftpRemotePath, after.ftpRemotePath},
        {QStringLiteral("filePrefix"), before.filePrefix, after.filePrefix},
        {QStringLiteral("ftpProtocol"), before.ftpProtocol, after.ftpProtocol},
        {QStringLiteral("serverActive"), before.serverActive, after.serverActive},
        {QStringLiteral("serverDeviceType"), before.serverDeviceType, after.serverDeviceType},
        {QStringLiteral("serverName"), before.serverName, after.serverName},
        {QStringLiteral("serverSendInterval"), before.serverSendInterval, after.serverSendInterval},
        {QStringLiteral("autoAddTransmit"), before.autoAddTransmit, after.autoAddTransmit},
        {QStringLiteral("serverStartTime"), before.serverStartTime, after.serverStartTime},
        {QStringLiteral("serverBaseFolder"), before.serverBaseFolder, after.serverBaseFolder},
        {QStringLiteral("serverTimeFolder"), before.serverTimeFolder, after.serverTimeFolder},
        {QStringLiteral("fileSuffix"), before.fileSuffix, after.fileSuffix},
        {QStringLiteral("pollInterval"), before.pollInterval, after.pollInterval},
        {QStringLiteral("monitorViewMode"), before.monitorViewMode, after.monitorViewMode},
        {QStringLiteral("monitorShowDigitalIO"), before.monitorShowDigitalIO,
         after.monitorShowDigitalIO},
        {QStringLiteral("alarmHysteresis"), before.alarmHysteresis, after.alarmHysteresis},
        {QStringLiteral("doFailSafeOnReconnect"), before.doFailSafeOnReconnect,
         after.doFailSafeOnReconnect},
        {QStringLiteral("serialPort"), before.serialPort, after.serialPort},
        {QStringLiteral("serialBaudrate"), before.serialBaudrate, after.serialBaudrate},
        {QStringLiteral("serialBytesize"), before.serialBytesize, after.serialBytesize},
        {QStringLiteral("serialParity"), before.serialParity, after.serialParity},
        {QStringLiteral("serialStopbits"), before.serialStopbits, after.serialStopbits},
        {QStringLiteral("modbusTcpEnabled"), before.modbusTcpEnabled, after.modbusTcpEnabled},
        {QStringLiteral("modbusTcpPort"), before.modbusTcpPort, after.modbusTcpPort},
        {QStringLiteral("modbusTcpBind"), before.modbusTcpBind, after.modbusTcpBind},
        {QStringLiteral("modbusTcpUnitId"), before.modbusTcpUnitId, after.modbusTcpUnitId},
        {QStringLiteral("restApiEnabled"), before.restApiEnabled, after.restApiEnabled},
        {QStringLiteral("restApiPort"), before.restApiPort, after.restApiPort},
        {QStringLiteral("restApiBind"), before.restApiBind, after.restApiBind},
        {QStringLiteral("uiLocale"), before.uiLocale, after.uiLocale},
        {QStringLiteral("theme"), before.theme, after.theme},
    });
}

bool SettingsController::checkPermission(Permission permission, const QString &action,
                                         const QString &deniedMessage)
{
    if (AuthService::authorize(permission))
        return true;

    AuditLogEntry entry = AuditTrail::entry(
        AuditTrail::localActor(), action, QStringLiteral("app_config"), QString(),
        AuditResult::Denied,
        AuditTrail::snapshot({{QStringLiteral("reason"), deniedMessage}}));
    AuditTrail::appendStandalone(entry);
    emit messageSent(QStringLiteral("Permission denied"), deniedMessage);
    return false;
}

QString SettingsController::ftpPassword() const {
    if (m_cfg.ftpPassword.isEmpty()) return {};
    return Crypto::decrypt(m_cfg.ftpPassword);
}
void SettingsController::setFtpPassword(const QString &v) {
    m_cfg.ftpPassword = v.isEmpty() ? QString() : Crypto::encrypt(v);
}

void SettingsController::setServerActive(bool v) {
    if (m_cfg.serverActive != v) {
        m_cfg.serverActive = v;
        emit serverActiveChanged();
    }
}

void SettingsController::setTheme(const QString &v) {
    const QString normalized = v.isEmpty() ? kDefaultTheme : v;
    if (m_cfg.theme == normalized)
        return;
    m_cfg.theme = normalized;
    emit themeChanged();
}

bool SettingsController::saveTheme(const QString &value) {
    if (!checkPermission(Permission::ConfigureSystem, QStringLiteral("settings.theme"),
                         QStringLiteral("Only administrators can change system settings.")))
        return false;

    const QString previous = m_cfg.theme;
    setTheme(value);
    if (previous == m_cfg.theme)
        return true;

    bool ok;
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        ok = saveConfigWithAudit(
            dao, db.get(), m_cfg, QStringLiteral("settings.theme"),
            AuditTrail::changes({{QStringLiteral("theme"), previous, m_cfg.theme}}));
    }
    return ok;
}

void SettingsController::loadConfig() {
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        m_cfg = dao.load();
    }
    emit configLoaded();
    emit monitorViewModeChanged();
    emit themeChanged();
    emit provisionQrChanged();
}

void SettingsController::saveConfig() {
    if (!checkPermission(Permission::ConfigureSystem, QStringLiteral("settings.save"),
                         QStringLiteral("Only administrators can change system settings.")))
        return;
    QStringList errors = validate();
    if (!errors.isEmpty()) {
        emit messageSent("Validation error", errors.join('\n'));
        return;
    }

    bool ok;
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        const AppConfig before = dao.load();

        // Auto-generate REST token on first enable
        if (m_cfg.restApiEnabled && m_cfg.restApiToken.trimmed().isEmpty())
            m_cfg.restApiToken = QUuid::createUuid().toString(QUuid::WithoutBraces).remove('-');

        ok = saveConfigWithAudit(dao, db.get(), m_cfg, QStringLiteral("settings.save"),
                                 auditChanges(before, m_cfg));
    }

    if (ok) {
        emit configLoaded();
        emit configSaved();
        emit provisionQrChanged();
        emit messageSent("Success", "Configuration saved.");
        if (Crypto::isDegraded())
            emit messageSent(QStringLiteral("Warning"),
                             QStringLiteral("Mã hóa không khả dụng — mật khẩu/token đang "
                                            "lưu ở dạng yếu. Kiểm tra quyền thư mục config "
                                            "và log để biết chi tiết."));
        if (!applyTimeSettings())
            emit messageSent(QStringLiteral("Warning"),
                             QStringLiteral("Configuration saved, but the system timezone "
                                            "could not be applied to the OS."));
    } else {
        emit messageSent("Error", "Failed to save configuration.");
    }
}

bool SettingsController::runTimedatectl(const QStringList &args) {
    QProcess proc;
    proc.start(QStringLiteral("timedatectl"), args);
    if (!proc.waitForStarted(2000)) {
        qWarning() << "[SettingsController] 'timedatectl' not available for" << args;
        return false;
    }
    if (!proc.waitForFinished(5000)) {
        proc.kill();
        qWarning() << "[SettingsController] 'timedatectl' timed out for" << args;
        return false;
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        qWarning() << "[SettingsController] 'timedatectl'" << args << "failed:"
                   << proc.readAllStandardError().trimmed();
        return false;
    }
    return true;
}

bool SettingsController::applyTimeSettings() {
    // m_cfg.timezone already stores an IANA zone id (e.g. "Etc/GMT-7") that
    // timedatectl accepts directly — see SettingsGeneralTab.qml combo box.
    // Empty falls back to Vietnam (the edge is a VN-only kiosk).
    QString zone = m_cfg.timezone.trimmed();
    if (zone.isEmpty())
        zone = QStringLiteral("Asia/Ho_Chi_Minh");
    const bool ok = runTimedatectl({QStringLiteral("set-timezone"), zone});
    // Enable systemd-timesyncd so the clock self-corrects once internet is
    // available — no in-app network code needed.
    runTimedatectl({QStringLiteral("set-ntp"), QStringLiteral("true")});
    return ok;
}

void SettingsController::syncSystemTime()
{
    // Boot-time sync (kiosk: no OS UI to configure date/time). Zone defaults
    // to Asia/Ho_Chi_Minh and is persisted, then applied to the OS.
    if (m_cfg.timezone.trimmed().isEmpty()) {
        m_cfg.timezone = QStringLiteral("Asia/Ho_Chi_Minh");
        ScopedDbConnection db;
        AppConfigDao dao(db);
        dao.save(m_cfg);
    }
    if (!applyTimeSettings())
        qWarning() << "[SettingsController] boot time sync failed (timedatectl)";
}

void SettingsController::saveSerialConfig(const QString &port, int baudrate,
                                           int bytesize, const QString &parity, int stopbits) {
    if (!checkPermission(Permission::ConfigureSystem, QStringLiteral("settings.serial"),
                         QStringLiteral("Only administrators can change connection settings.")))
        return;

    bool ok;
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        const AppConfig before = dao.load();

        m_cfg.serialPort     = port;
        m_cfg.serialBaudrate = baudrate;
        m_cfg.serialBytesize = bytesize;
        m_cfg.serialParity   = parity;
        m_cfg.serialStopbits = stopbits;

        ok = saveConfigWithAudit(dao, db.get(), m_cfg, QStringLiteral("settings.serial"),
                                 auditChanges(before, m_cfg));
    }
    if (!ok) {
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("Failed to save connection settings."));
        loadConfig(); // RAM phải khớp DB sau khi rollback
        return;
    }
    emit configLoaded();
}

void SettingsController::regenerateRestToken() {
    if (!checkPermission(Permission::ConfigureSystem,
                         QStringLiteral("settings.rest_token.regenerate"),
                         QStringLiteral("Only administrators can change the REST token.")))
        return;

    bool ok;
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        QSqlDatabase &sql = db.get();
        ok = sql.transaction();
        if (ok) {
            // Token mới chỉ lưu trong DB/RAM; audit không bao giờ chứa token.
            m_cfg.restApiToken = dao.generateAndSaveToken();
            AuditLogEntry entry = AuditTrail::entry(
                AuditTrail::localActor(), QStringLiteral("settings.rest_token.regenerate"),
                QStringLiteral("app_config"), QString::number(m_cfg.id));
            ok = AuditTrail::append(sql, entry);
            if (ok)
                ok = sql.commit();
            if (!ok)
                sql.rollback();
        }
    }
    if (!ok) {
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("Failed to change the REST token."));
        return;
    }
    emit configLoaded();
    emit configSaved();
    emit provisionQrChanged();
    emit messageSent("REST API", "Token changed — scan QR again in Central App.");
}

void SettingsController::rebootSystem() {
    if (!checkPermission(Permission::ConfigureSystem, QStringLiteral("system.reboot"),
                         QStringLiteral("Only administrators can reboot the device.")))
        return;
    qInfo() << "[SettingsController] System reboot requested";
    // `systemctl reboot` routes through logind; the unprivileged kiosk user is
    // authorised by the polkit rule shipped with the package.
    const bool ok = QProcess::startDetached(QStringLiteral("systemctl"),
                                            {QStringLiteral("reboot")});
    AuditLogEntry entry = AuditTrail::entry(
        AuditTrail::localActor(), QStringLiteral("system.reboot"), QStringLiteral("system"),
        QString(), ok ? AuditResult::Ok : AuditResult::Failed);
    AuditTrail::appendStandalone(entry);

    if (!ok) {
        qWarning() << "[SettingsController] Failed to invoke 'systemctl reboot'";
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("Failed to reboot the system."));
    }
}

bool SettingsController::provisionQrAvailable() const
{
    return m_cfg.restApiEnabled && !m_cfg.restApiToken.trimmed().isEmpty();
}

bool SettingsController::provisionQrStale() const
{
    return !m_qrTokenSnapshot.isEmpty()
        && m_qrTokenSnapshot != m_cfg.restApiToken;
}

QString SettingsController::provisionHost() const
{
    const QString bind = m_cfg.restApiBind.trimmed();
    if (!bind.isEmpty() && bind != kBindAnyIPv4
        && bind != kBindAnyIPv6)
        return bind;
    return LanIp::primaryLanIp();
}

QString SettingsController::buildProvisionJson() const
{
    QJsonObject obj{
        {QStringLiteral("schema"), kProvisionSchema},
        {QStringLiteral("api_token"), m_cfg.restApiToken},
        {QStringLiteral("host"), provisionHost()},
        {QStringLiteral("api_port"), m_cfg.restApiPort},
        {QStringLiteral("modbus_port"), m_cfg.modbusTcpPort},
        {QStringLiteral("modbus_unit_id"), m_cfg.modbusTcpUnitId},
    };
    if (!m_cfg.stationCode.isEmpty())
        obj.insert(QStringLiteral("station_code"), m_cfg.stationCode);
    if (!m_cfg.stationName.isEmpty())
        obj.insert(QStringLiteral("station_name"), m_cfg.stationName);
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QString SettingsController::get_provision_qr_base64()
{
    if (!provisionQrAvailable()) {
        emit messageSent(QStringLiteral("REST API"),
                         QStringLiteral("Enable REST API and save a token before generating QR."));
        return {};
    }
    m_qrTokenSnapshot = m_cfg.restApiToken;
    emit provisionQrChanged();
    return ProvisionQr::pngBase64(buildProvisionJson());
}

QStringList SettingsController::validate() const {
    QStringList errors;
    if (m_cfg.pollInterval < 1)
        errors << "Poll interval must be at least 1 second.";
    if (m_cfg.ftpPort < 1 || m_cfg.ftpPort > 65535)
        errors << "FTP port must be between 1 and 65535.";
    if (m_cfg.modbusTcpPort < 1 || m_cfg.modbusTcpPort > 65535)
        errors << "Modbus TCP port must be between 1 and 65535.";
    if (m_cfg.modbusTcpUnitId < 1 || m_cfg.modbusTcpUnitId > 247)
        errors << "Modbus TCP Unit ID must be between 1 and 247.";
    if (m_cfg.modbusTcpBind.trimmed().isEmpty())
        errors << "Modbus TCP bind address is required.";
    if (m_cfg.restApiPort < 1 || m_cfg.restApiPort > 65535)
        errors << "REST API port must be between 1 and 65535.";
    if (m_cfg.restApiBind.trimmed().isEmpty())
        errors << "REST API bind address is required.";
    if (m_cfg.restApiEnabled && m_cfg.modbusTcpEnabled
        && m_cfg.restApiPort == m_cfg.modbusTcpPort)
        errors << "REST API port must differ from Modbus TCP port.";
    if (m_cfg.serverActive && m_cfg.filePrefix.trimmed().isEmpty())
        errors << "File prefix is required when server transmission is active.";
    return errors;
}
