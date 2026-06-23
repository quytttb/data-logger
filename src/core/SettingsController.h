#pragma once
#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>
#include "data/models/AppConfig.h"
#include "utils/QmlSingleton.h"

// Exposes AppConfig to QML and handles save/load.
class SettingsController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Station
    Q_PROPERTY(QString stationCode   READ stationCode   WRITE setStationCode   NOTIFY configLoaded)
    Q_PROPERTY(QString stationName   READ stationName   WRITE setStationName   NOTIFY configLoaded)

    // General
    Q_PROPERTY(QString timeFormat    READ timeFormat    WRITE setTimeFormat    NOTIFY configLoaded)
    Q_PROPERTY(QString dateFormat    READ dateFormat    WRITE setDateFormat    NOTIFY configLoaded)
    Q_PROPERTY(QString timezone      READ timezone      WRITE setTimezone      NOTIFY configLoaded)
    Q_PROPERTY(bool   autoSyncTime   READ autoSyncTime  WRITE setAutoSyncTime  NOTIFY configLoaded)
    Q_PROPERTY(bool   buzzerEnable   READ buzzerEnable  WRITE setBuzzerEnable  NOTIFY configLoaded)

    // FTP
    Q_PROPERTY(QString ftpAddress    READ ftpAddress    WRITE setFtpAddress    NOTIFY configLoaded)
    Q_PROPERTY(int    ftpPort        READ ftpPort       WRITE setFtpPort       NOTIFY configLoaded)
    Q_PROPERTY(QString ftpUsername   READ ftpUsername   WRITE setFtpUsername   NOTIFY configLoaded)
    Q_PROPERTY(QString ftpPassword   READ ftpPassword   WRITE setFtpPassword   NOTIFY configLoaded)
    Q_PROPERTY(QString ftpRemotePath READ ftpRemotePath WRITE setFtpRemotePath NOTIFY configLoaded)
    Q_PROPERTY(QString ftpPrefix     READ ftpPrefix     WRITE setFtpPrefix     NOTIFY configLoaded)

    // Polling
    Q_PROPERTY(int    pollInterval   READ pollInterval  WRITE setPollInterval  NOTIFY configLoaded)

    // Serial
    Q_PROPERTY(QString serialPort    READ serialPort    WRITE setSerialPort    NOTIFY configLoaded)
    Q_PROPERTY(int    serialBaudrate READ serialBaudrate WRITE setSerialBaudrate NOTIFY configLoaded)
    Q_PROPERTY(int    serialBytesize READ serialBytesize WRITE setSerialBytesize NOTIFY configLoaded)
    Q_PROPERTY(QString serialParity  READ serialParity  WRITE setSerialParity  NOTIFY configLoaded)
    Q_PROPERTY(int    serialStopbits READ serialStopbits WRITE setSerialStopbits NOTIFY configLoaded)

    // Server / Transmission
    Q_PROPERTY(bool   serverActive   READ serverActive  WRITE setServerActive  NOTIFY serverActiveChanged)
    Q_PROPERTY(QString serverDeviceType READ serverDeviceType WRITE setServerDeviceType NOTIFY configLoaded)
    Q_PROPERTY(QString serverName    READ serverName    WRITE setServerName    NOTIFY configLoaded)
    Q_PROPERTY(int    serverSendInterval READ serverSendInterval WRITE setServerSendInterval NOTIFY configLoaded)
    Q_PROPERTY(QString serverStartTime  READ serverStartTime  WRITE setServerStartTime  NOTIFY configLoaded)
    Q_PROPERTY(QString serverBaseFolder READ serverBaseFolder WRITE setServerBaseFolder NOTIFY configLoaded)
    Q_PROPERTY(QString serverTimeFolder READ serverTimeFolder WRITE setServerTimeFolder NOTIFY configLoaded)
    Q_PROPERTY(QString serverFileSuffix READ serverFileSuffix WRITE setServerFileSuffix NOTIFY configLoaded)

    // Modbus TCP
    Q_PROPERTY(bool   modbusTcpEnabled READ modbusTcpEnabled WRITE setModbusTcpEnabled NOTIFY configLoaded)
    Q_PROPERTY(int    modbusTcpPort    READ modbusTcpPort    WRITE setModbusTcpPort    NOTIFY configLoaded)
    Q_PROPERTY(QString modbusTcpBind   READ modbusTcpBind    WRITE setModbusTcpBind    NOTIFY configLoaded)
    Q_PROPERTY(int    modbusTcpUnitId  READ modbusTcpUnitId  WRITE setModbusTcpUnitId  NOTIFY configLoaded)

    // REST API
    Q_PROPERTY(bool   restApiEnabled READ restApiEnabled WRITE setRestApiEnabled NOTIFY configLoaded)
    Q_PROPERTY(int    restApiPort    READ restApiPort    WRITE setRestApiPort    NOTIFY configLoaded)
    Q_PROPERTY(QString restApiBind   READ restApiBind    WRITE setRestApiBind    NOTIFY configLoaded)
    Q_PROPERTY(QString restApiToken  READ restApiToken                           NOTIFY configLoaded)
    Q_PROPERTY(int    configRevision READ configRevision                         NOTIFY configLoaded)
    Q_PROPERTY(QString theme         READ theme         WRITE setTheme         NOTIFY themeChanged)
    Q_PROPERTY(bool   provisionQrAvailable READ provisionQrAvailable             NOTIFY provisionQrChanged)
    Q_PROPERTY(bool   provisionQrStale     READ provisionQrStale               NOTIFY provisionQrChanged)

public:
    explicit SettingsController(QObject *parent);

    DECLARE_QML_SINGLETON(SettingsController)

    // Property getters
    QString stationCode()   const { return m_cfg.stationCode; }
    QString stationName()   const { return m_cfg.stationName; }
    QString timeFormat()    const { return m_cfg.timeFormat; }
    QString dateFormat()    const { return m_cfg.dateFormat; }
    QString timezone()      const { return m_cfg.timezone; }
    bool   autoSyncTime()   const { return m_cfg.autoSyncTime; }
    bool   buzzerEnable()   const { return m_cfg.buzzerEnable; }
    QString ftpAddress()    const { return m_cfg.ftpAddress; }
    int    ftpPort()        const { return m_cfg.ftpPort; }
    QString ftpUsername()   const { return m_cfg.ftpUsername; }
    QString ftpPassword()   const;  // decrypts on read
    QString ftpRemotePath() const { return m_cfg.ftpRemotePath; }
    QString ftpPrefix()     const { return m_cfg.ftpPrefix; }
    int    pollInterval()   const { return m_cfg.pollInterval; }
    QString serialPort()    const { return m_cfg.serialPort; }
    int    serialBaudrate() const { return m_cfg.serialBaudrate; }
    int    serialBytesize() const { return m_cfg.serialBytesize; }
    QString serialParity()  const { return m_cfg.serialParity; }
    int    serialStopbits() const { return m_cfg.serialStopbits; }
    bool   serverActive()   const { return m_cfg.serverActive; }
    QString serverDeviceType() const { return m_cfg.serverDeviceType; }
    QString serverName()    const { return m_cfg.serverName; }
    int    serverSendInterval() const { return m_cfg.serverSendInterval; }
    QString serverStartTime()   const { return m_cfg.serverStartTime; }
    QString serverBaseFolder()  const { return m_cfg.serverBaseFolder; }
    QString serverTimeFolder()  const { return m_cfg.serverTimeFolder; }
    QString serverFileSuffix()  const { return m_cfg.serverFileSuffix; }
    bool   modbusTcpEnabled()   const { return m_cfg.modbusTcpEnabled; }
    int    modbusTcpPort()      const { return m_cfg.modbusTcpPort; }
    QString modbusTcpBind()     const { return m_cfg.modbusTcpBind; }
    int    modbusTcpUnitId()    const { return m_cfg.modbusTcpUnitId; }
    bool   restApiEnabled()     const { return m_cfg.restApiEnabled; }
    int    restApiPort()        const { return m_cfg.restApiPort; }
    QString restApiBind()       const { return m_cfg.restApiBind; }
    QString restApiToken()      const { return m_cfg.restApiToken; }
    int    configRevision()     const { return m_cfg.configRevision; }
    QString theme()             const { return m_cfg.theme; }
    bool   provisionQrAvailable() const;
    bool   provisionQrStale()     const;

    // Property setters
    void setStationCode(const QString &v)   { m_cfg.stationCode = v; }
    void setStationName(const QString &v)   { m_cfg.stationName = v; }
    void setTimeFormat(const QString &v)    { m_cfg.timeFormat = v; }
    void setDateFormat(const QString &v)    { m_cfg.dateFormat = v; }
    void setTimezone(const QString &v)      { m_cfg.timezone = v; }
    void setAutoSyncTime(bool v)            { m_cfg.autoSyncTime = v; }
    void setBuzzerEnable(bool v)            { m_cfg.buzzerEnable = v; }
    void setFtpAddress(const QString &v)    { m_cfg.ftpAddress = v; }
    void setFtpPort(int v)                  { m_cfg.ftpPort = v; }
    void setFtpUsername(const QString &v)   { m_cfg.ftpUsername = v; }
    void setFtpPassword(const QString &v);  // encrypts before storing
    void setFtpRemotePath(const QString &v) { m_cfg.ftpRemotePath = v; }
    void setFtpPrefix(const QString &v)     { m_cfg.ftpPrefix = v; }
    void setPollInterval(int v)             { m_cfg.pollInterval = v; }
    void setSerialPort(const QString &v)    { m_cfg.serialPort = v; }
    void setSerialBaudrate(int v)           { m_cfg.serialBaudrate = v; }
    void setSerialBytesize(int v)           { m_cfg.serialBytesize = v; }
    void setSerialParity(const QString &v)  { m_cfg.serialParity = v; }
    void setSerialStopbits(int v)           { m_cfg.serialStopbits = v; }
    void setServerActive(bool v);
    void setServerDeviceType(const QString &v) { m_cfg.serverDeviceType = v; }
    void setServerName(const QString &v)    { m_cfg.serverName = v; }
    void setServerSendInterval(int v)       { m_cfg.serverSendInterval = v; }
    void setServerStartTime(const QString &v)  { m_cfg.serverStartTime = v; }
    void setServerBaseFolder(const QString &v) { m_cfg.serverBaseFolder = v; }
    void setServerTimeFolder(const QString &v) { m_cfg.serverTimeFolder = v; }
    void setServerFileSuffix(const QString &v) { m_cfg.serverFileSuffix = v; }
    void setModbusTcpEnabled(bool v)        { m_cfg.modbusTcpEnabled = v; }
    void setModbusTcpPort(int v)            { m_cfg.modbusTcpPort = v; }
    void setModbusTcpBind(const QString &v) { m_cfg.modbusTcpBind = v; }
    void setModbusTcpUnitId(int v)          { m_cfg.modbusTcpUnitId = v; }
    void setRestApiEnabled(bool v)          { m_cfg.restApiEnabled = v; }
    void setRestApiPort(int v)              { m_cfg.restApiPort = v; }
    void setRestApiBind(const QString &v)   { m_cfg.restApiBind = v; }
    void setTheme(const QString &v);

    // Access the loaded config struct (read-only, for MonitorController startup)
    const AppConfig &config() const { return m_cfg; }

public slots:
    void loadConfig();
    void saveConfig();
    Q_INVOKABLE void saveSerialConfig(const QString &port, int baudrate,
                                      int bytesize, const QString &parity, int stopbits);
    Q_INVOKABLE void regenerateRestToken();
    Q_INVOKABLE QString get_provision_qr_base64();
    Q_INVOKABLE bool saveTheme(const QString &value);
    Q_INVOKABLE QVariantMap coefficientUiState(const QString &coeffJson) const;
    Q_INVOKABLE QString buildCoefficientJson(int mode, const QString &legacyJson,
                                              const QString &s0, const QString &s1,
                                              const QString &s2, const QString &s3);
    // Reboot the host machine (kiosk has no exit button). Relies on a polkit rule
    // shipped in the package so the unprivileged kiosk user may reboot.
    Q_INVOKABLE void rebootSystem();

signals:
    void configLoaded();
    void configSaved();
    void themeChanged();
    void serverActiveChanged();
    void provisionQrChanged();
    void messageSent(QString title, QString body);

private:
    QString buildProvisionJson() const;
    QString provisionHost() const;

    QStringList validate() const;

    AppConfig m_cfg;
    QString   m_qrTokenSnapshot;
};
