#include "AppPaths.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QProcessEnvironment>

namespace AppPaths {

namespace {
const QString kDataSubdir   = QStringLiteral("/data");
const QString kConfigSubdir = QStringLiteral("/config");
const QString kLogSubdir    = QStringLiteral("/logs");
}

static QString binDir() {
    return QCoreApplication::applicationDirPath();
}

QString dataDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_DATA_DIR");
    return override.isEmpty() ? binDir() + kDataSubdir : override;
}

QString configDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_CONFIG_DIR");
    return override.isEmpty() ? binDir() + kConfigSubdir : override;
}

QString logDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_LOG_DIR");
    return override.isEmpty() ? binDir() + kLogSubdir : override;
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
