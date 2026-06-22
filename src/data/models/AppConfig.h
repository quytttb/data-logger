#pragma once
#include <QString>

struct AppConfig {
    int id = 0;

    // Station info
    QString stationCode = QStringLiteral("DL-001");
    QString stationName = QStringLiteral("Data Logger");

    // General
    QString timeFormat  = "HH:mm:ss";
    QString dateFormat  = "dd/MM/yyyy";
    QString timezone    = "UTC+7";
    bool autoSyncTime   = false;
    bool buzzerEnable   = false;

    // FTP
    QString ftpAddress;
    int ftpPort         = 21;
    QString ftpUsername;
    QString ftpPassword;   // stored encrypted
    QString ftpRemotePath = "/";
    QString ftpPrefix;
    QString ftpProtocol = QStringLiteral("sftp");  // "ftp" | "sftp"

    // Server / Transmission
    bool serverActive          = false;
    QString serverDeviceType   = "Standard";
    QString serverName;
    int serverSendInterval     = 5;
    QString serverStartTime    = "00:00";
    QString serverBaseFolder;
    QString serverTimeFolder   = "yyyy/MM/dd";
    QString serverFileSuffix   = "yyyyMMddHHmmss";

    // Polling
    int pollInterval = 3;

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
