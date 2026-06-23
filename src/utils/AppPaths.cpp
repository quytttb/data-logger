#include "AppPaths.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QStandardPaths>

namespace AppPaths {

namespace {
const QString kDataSubdir   = QStringLiteral("/data");
const QString kConfigSubdir = QStringLiteral("/config");
const QString kLogSubdir    = QStringLiteral("/logs");

// Per-user writable base, e.g. ~/.local/share/DATALOGGER/DataLogger.
// Used when no explicit DATALOGGER_*_DIR override is set, so the app keeps
// working when installed read-only under /usr (Debian package / kiosk mode)
// instead of writing next to the binary in /usr/bin.
QString writableBase() {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.datalogger");
    return base;
}
}

static QString binDir() {
    return QCoreApplication::applicationDirPath();
}

QString dataDir() {
    QString override = qEnvironmentVariable("DATALOGGER_DATA_DIR");
    return override.isEmpty() ? writableBase() + kDataSubdir : override;
}

QString configDir() {
    QString override = qEnvironmentVariable("DATALOGGER_CONFIG_DIR");
    return override.isEmpty() ? writableBase() + kConfigSubdir : override;
}

QString logDir() {
    QString override = qEnvironmentVariable("DATALOGGER_LOG_DIR");
    return override.isEmpty() ? writableBase() + kLogSubdir : override;
}

QString appIconPath() {
    QString png = binDir() + "/resources/app-icon.png";
    if (QFileInfo::exists(png)) return png;
    QString svg = binDir() + "/resources/app-icon.svg";
    if (QFileInfo::exists(svg)) return svg;
    return {};
}

void ensureDirectories() {
    QDir().mkpath(dataDir());
    QDir().mkpath(configDir());
    QDir().mkpath(logDir());
}

} // namespace AppPaths
