#include "ReportNaming.h"

namespace ReportNaming {

QString buildFileName(const AppConfig &cfg, const QDateTime &ts)
{
    const QString suffix = cfg.fileSuffix.isEmpty()
        ? QStringLiteral("yyyyMMddHHmmss")
        : cfg.fileSuffix;
    return cfg.filePrefix + ts.toString(suffix) + QStringLiteral(".txt");
}

QString buildRemoteDir(const AppConfig &cfg, const QDateTime &ts)
{
    QString base = cfg.ftpRemotePath;
    if (base.isEmpty())
        base = QStringLiteral("/");
    if (!base.endsWith(QLatin1Char('/')))
        base += QLatin1Char('/');

    if (!cfg.serverBaseFolder.isEmpty()) {
        QString folder = cfg.serverBaseFolder;
        if (folder.startsWith(QLatin1Char('/')))
            folder = folder.mid(1);
        if (!folder.endsWith(QLatin1Char('/')))
            folder += QLatin1Char('/');
        base += folder;
    }

    if (!cfg.serverTimeFolder.isEmpty()) {
        base += ts.toString(cfg.serverTimeFolder);
        if (!base.endsWith(QLatin1Char('/')))
            base += QLatin1Char('/');
    }

    return base;
}

} // namespace ReportNaming
