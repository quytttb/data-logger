#include "AppPaths.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QProcessEnvironment>

namespace AppPaths {

static QString binDir() {
    return QCoreApplication::applicationDirPath();
}

QString dataDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_DATA_DIR");
    return override.isEmpty() ? binDir() + "/data" : override;
}

QString configDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_CONFIG_DIR");
    return override.isEmpty() ? binDir() + "/config" : override;
}

QString logDir() {
    auto env = QProcessEnvironment::systemEnvironment();
    QString override = env.value("DATALOGGER_LOG_DIR");
    return override.isEmpty() ? binDir() + "/logs" : override;
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
