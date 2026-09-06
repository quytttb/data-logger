#pragma once

#include <QString>
#include <QTimeZone>

// Giá trị mặc định dùng chung giữa model cấu hình, service và QML.
namespace AppDefaults {

inline const QString stationName = QStringLiteral("Data Logger");
inline const QString timeFormat = QStringLiteral("HH:mm:ss");
inline const QString dateFormat = QStringLiteral("dd/MM/yyyy");
inline const QString uiTimeFormat = QStringLiteral("HH:mm:ss");
inline const QString uiDateFormat = QStringLiteral("dd/MM/yyyy");
// Không hardcode UTC+7: image Raspberry Pi có thể được cài với timezone khác.
inline QString systemTimezone() { return QTimeZone::systemTimeZoneId(); }
inline const QString timezone = systemTimezone();

constexpr int ftpPort = 21;
inline const QString ftpRemotePath = QStringLiteral("/");
inline const QString ftpProtocol = QStringLiteral("sftp");

constexpr int pollInterval = 3;

inline const QString serialPort = QStringLiteral("/dev/ttyUSB0");
constexpr int serialBaudrate = 9600;
constexpr int serialBytesize = 8;
inline const QString serialParity = QStringLiteral("N");
constexpr int serialStopbits = 1;

inline const QString bindAnyIPv4 = QStringLiteral("0.0.0.0");
constexpr int modbusTcpPort = 5020;
constexpr int modbusTcpUnitId = 1;
constexpr int restApiPort = 8080;

inline const QString serverDeviceType = QStringLiteral("Standard");
constexpr int serverSendInterval = 5;
inline const QString serverStartTime = QStringLiteral("00:00");
inline const QString serverTimeFolder = QStringLiteral("yyyy/MM/dd");
inline const QString fileSuffix = QStringLiteral("yyyyMMddHHmmss");

constexpr int configRevision = 1;
inline const QString uiLocale = QStringLiteral("vi");
inline const QString theme = QStringLiteral("dark");

} // namespace AppDefaults
