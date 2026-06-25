#include "SettingsController.h"
#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "utils/crypto/Crypto.h"
#include "utils/network/LanIp.h"
#include "utils/provision/ProvisionQr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QProcess>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <cmath>

IMPLEMENT_QML_SINGLETON(SettingsController)

namespace {
const QString kDefaultTheme    = QStringLiteral("dark");
const QString kBindAnyIPv4     = QStringLiteral("0.0.0.0");
const QString kBindAnyIPv6     = QStringLiteral("::");
const QString kProvisionSchema = QStringLiteral("central-logger-provision/v1");
}

SettingsController::SettingsController(QObject *parent) : QObject(parent) {}

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
    setTheme(value);
    ScopedDbConnection db;
    AppConfigDao dao(db);
    return dao.save(m_cfg);
}

void SettingsController::loadConfig() {
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        m_cfg = dao.load();
    }
    emit configLoaded();
    emit themeChanged();
    emit provisionQrChanged();
}

void SettingsController::saveConfig() {
    QStringList errors = validate();
    if (!errors.isEmpty()) {
        emit messageSent("Validation error", errors.join('\n'));
        return;
    }

    bool ok;
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);

        // Auto-generate REST token on first enable
        if (m_cfg.restApiEnabled && m_cfg.restApiToken.trimmed().isEmpty())
            m_cfg.restApiToken = QUuid::createUuid().toString(QUuid::WithoutBraces).remove('-');

        ok = dao.save(m_cfg);
    }

    if (ok) {
        emit configLoaded();
        emit configSaved();
        emit provisionQrChanged();
        emit messageSent("Success", "Configuration saved.");
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
    const QString zone = m_cfg.timezone.trimmed();
    if (zone.isEmpty()) {
        qWarning() << "[SettingsController] Empty timezone; skipping set-timezone";
        return false;
    }
    return runTimedatectl({QStringLiteral("set-timezone"), zone});
}

void SettingsController::saveSerialConfig(const QString &port, int baudrate,
                                           int bytesize, const QString &parity, int stopbits) {
    m_cfg.serialPort     = port;
    m_cfg.serialBaudrate = baudrate;
    m_cfg.serialBytesize = bytesize;
    m_cfg.serialParity   = parity;
    m_cfg.serialStopbits = stopbits;

    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        dao.save(m_cfg);
    }
    emit configLoaded();
}

void SettingsController::regenerateRestToken() {
    {
        ScopedDbConnection db;
        AppConfigDao dao(db);
        m_cfg.restApiToken = dao.generateAndSaveToken();
    }
    emit configLoaded();
    emit configSaved();
    emit provisionQrChanged();
    emit messageSent("REST API", "Token changed — scan QR again in Central App.");
}

void SettingsController::rebootSystem() {
    qInfo() << "[SettingsController] System reboot requested";
    // `systemctl reboot` routes through logind; the unprivileged kiosk user is
    // authorised by the polkit rule shipped with the package.
    if (!QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("reboot")})) {
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
    return errors;
}

QVariantMap SettingsController::coefficientUiState(const QString &coeffJson) const {
    QVariantMap blank {
        {"mode", 0}, {"linearA", "1"}, {"linearB", "0"},
        {"rawMin", "4000"}, {"rawMax", "20000"},
        {"scaleMin", "4"}, {"scaleMax", "20"}, {"legacyJson", "{}"}
    };

    QString raw = coeffJson.trimmed().isEmpty() ? "{}" : coeffJson.trimmed();
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        blank["mode"] = 3; blank["legacyJson"] = raw; return blank;
    }
    QJsonObject obj = doc.object();
    if (obj.isEmpty()) return blank;
    if (obj.contains("coeffs")) { blank["mode"] = 3; blank["legacyJson"] = raw; return blank; }
    if (obj.contains("a")) {
        double a = obj["a"].toDouble(1.0), b = obj["b"].toDouble(0.0);
        if (!std::isfinite(a) || !std::isfinite(b)) { blank["mode"] = 3; blank["legacyJson"] = raw; return blank; }
        return {{"mode", 1}, {"linearA", QString::number(a)}, {"linearB", QString::number(b)},
                {"rawMin", "4000"}, {"rawMax", "20000"}, {"scaleMin", "4"}, {"scaleMax", "20"}, {"legacyJson", "{}"}};
    }
    blank["mode"] = 3; blank["legacyJson"] = raw; return blank;
}

QString SettingsController::buildCoefficientJson(int mode, const QString &legacyJson,
                                                   const QString &s0, const QString &s1,
                                                   const QString &s2, const QString &s3) {
    auto parseDouble = [&](const QString &label, const QString &s) -> std::pair<double, QString> {
        QString t = s.trimmed().replace(',', '.');
        if (t.isEmpty()) return {0, label + " is required."};
        bool ok; double v = t.toDouble(&ok);
        if (!ok || !std::isfinite(v)) return {0, label + ": invalid number."};
        return {v, {}};
    };

    if (mode == 0) return "{}";
    if (mode == 1) {
        auto [a, ea] = parseDouble("Gain (a)", s0);
        auto [b, eb] = parseDouble("Offset (b)", s1);
        if (!ea.isEmpty()) { emit messageSent("Validation error", ea); return {}; }
        if (!eb.isEmpty()) { emit messageSent("Validation error", eb); return {}; }
        return QStringLiteral("{\"a\":%1,\"b\":%2}").arg(a).arg(b);
    }
    if (mode == 2) {
        auto [r0, e0] = parseDouble("Raw Min", s0);
        auto [r1, e1] = parseDouble("Raw Max", s1);
        auto [y0, e2] = parseDouble("Scale Min", s2);
        auto [y1, e3] = parseDouble("Scale Max", s3);
        for (const auto &e : {e0, e1, e2, e3})
            if (!e.isEmpty()) { emit messageSent("Validation error", e); return {}; }
        double denom = r1 - r0;
        if (denom == 0) { emit messageSent("Validation error", "Raw Max must differ from Raw Min."); return {}; }
        double a = (y1 - y0) / denom, b = y0 - a * r0;
        return QStringLiteral("{\"a\":%1,\"b\":%2}").arg(a).arg(b);
    }
    if (mode == 3) {
        QString t = legacyJson.trimmed().isEmpty() ? "{}" : legacyJson.trimmed();
        QJsonParseError err;
        QJsonDocument::fromJson(t.toUtf8(), &err);
        if (err.error != QJsonParseError::NoError) { emit messageSent("Validation error", "Invalid JSON: " + err.errorString()); return {}; }
        return t;
    }
    emit messageSent("Validation error", "Unknown scaling mode.");
    return {};
}
