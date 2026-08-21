#pragma once
#include <QString>
#include "utils/system/AppDefaults.h"

struct AppConfig {
    int id = 0;

    // Station info — stationCode is left empty here so AppConfigDao::load()
    // assigns a default (DeviceId::stationCode()) on first use when empty.
    // Device ID (hardware) is always derived at runtime via DeviceId::stationCode().
    QString stationCode;
    QString stationName = AppDefaults::stationName;

    // General
    QString timeFormat  = AppDefaults::timeFormat;
    QString dateFormat  = AppDefaults::dateFormat;
    QString timezone    = AppDefaults::timezone;
    bool buzzerEnable   = false;

    // FTP
    QString ftpAddress;
    int ftpPort         = AppDefaults::ftpPort;
    QString ftpUsername;
    QString ftpPassword;   // stored encrypted
    QString ftpRemotePath = AppDefaults::ftpRemotePath;
    QString filePrefix;
    QString ftpProtocol = AppDefaults::ftpProtocol;  // "ftp" | "sftp"

    // Server / Transmission
    bool serverActive          = false;
    QString serverDeviceType   = AppDefaults::serverDeviceType;
    QString serverName;
    int serverSendInterval     = AppDefaults::serverSendInterval;
    bool autoAddTransmit       = true;
    QString serverStartTime    = AppDefaults::serverStartTime;
    QString serverBaseFolder;
    QString serverTimeFolder   = AppDefaults::serverTimeFolder;
    QString fileSuffix         = AppDefaults::fileSuffix;

    // Polling
    int pollInterval = AppDefaults::pollInterval;

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
    QString serialPort       = AppDefaults::serialPort;
    int serialBaudrate       = AppDefaults::serialBaudrate;
    int serialBytesize       = AppDefaults::serialBytesize;
    QString serialParity     = AppDefaults::serialParity;
    int serialStopbits       = AppDefaults::serialStopbits;

    // Modbus TCP Server
    bool modbusTcpEnabled    = false;
    int modbusTcpPort        = AppDefaults::modbusTcpPort;
    QString modbusTcpBind    = AppDefaults::bindAnyIPv4;
    int modbusTcpUnitId      = AppDefaults::modbusTcpUnitId;

    // REST API
    bool restApiEnabled      = false;
    int restApiPort          = AppDefaults::restApiPort;
    QString restApiBind      = AppDefaults::bindAnyIPv4;
    QString restApiToken;
    int configRevision       = AppDefaults::configRevision;

    QString uiLocale = AppDefaults::uiLocale;
    QString theme = AppDefaults::theme;
};
