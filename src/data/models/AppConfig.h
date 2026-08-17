#pragma once
#include <QString>

struct AppConfig {
    int id = 0;

    // Station info — stationCode is left empty here so AppConfigDao::load()
    // assigns a default (DeviceId::stationCode()) on first use when empty.
    // Device ID (hardware) is always derived at runtime via DeviceId::stationCode().
    QString stationCode;
    QString stationName = QStringLiteral("Data Logger");

    // General
    QString timeFormat  = "HH:mm:ss";
    QString dateFormat  = "dd/MM/yyyy";
    QString timezone    = "Etc/GMT-7";  // IANA id for UTC+7 (POSIX sign inverted)
    bool buzzerEnable   = false;

    // FTP
    QString ftpAddress;
    int ftpPort         = 21;
    QString ftpUsername;
    QString ftpPassword;   // stored encrypted
    QString ftpRemotePath = "/";
    QString filePrefix;
    QString ftpProtocol = QStringLiteral("sftp");  // "ftp" | "sftp"

    // Server / Transmission
    bool serverActive          = false;
    QString serverDeviceType   = "Standard";
    QString serverName;
    int serverSendInterval     = 5;
    bool autoAddTransmit       = true;
    QString serverStartTime    = "00:00";
    QString serverBaseFolder;
    QString serverTimeFolder   = "yyyy/MM/dd";
    QString fileSuffix         = "yyyyMMddHHmmss";

    // Polling
    int pollInterval = 3;

    // Alarm behaviour (audit M5)
    // Absolute hysteresis applied when RELEASING a min/max alarm so relays do
    // not chatter around a threshold. 0 = legacy behaviour (no hysteresis).
    double alarmHysteresis = 0.0;

    // DO fail-safe policy (audit M5). true = force every DO coil OFF on
    // (re)connect so a stale latched relay can never disagree with the app;
    // false = leave the physical coil state as-is and let the next poll
    // converge it from the recomputed alarm states.
    bool doFailSafeOnReconnect = true;

    // Serial (RS-485)
    QString serialPort       = "/dev/ttyUSB0";
    int serialBaudrate       = 9600;
    int serialBytesize       = 8;
    QString serialParity     = "N";
    int serialStopbits       = 1;

    // Modbus TCP Server
    bool modbusTcpEnabled    = false;
    int modbusTcpPort        = 5020;
    QString modbusTcpBind    = "0.0.0.0";
    int modbusTcpUnitId      = 1;

    // REST API
    bool restApiEnabled      = false;
    int restApiPort          = 8080;
    QString restApiBind      = "0.0.0.0";
    QString restApiToken;
    int configRevision       = 1;

    QString uiLocale = "vi";
    QString theme = "dark";
};
