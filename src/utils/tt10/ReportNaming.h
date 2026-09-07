#pragma once
#include "data/models/AppConfig.h"
#include <QDateTime>
#include <QString>

namespace ReportNaming {

QString buildFileName(const AppConfig &cfg, const QDateTime &ts);
QString buildRemoteDir(const AppConfig &cfg, const QDateTime &ts);
// Full "dir + file" string shown in Settings as a live preview —
// the single source of truth QML must use instead of rebuilding it in JS.
QString buildPreviewPath(const AppConfig &cfg, const QDateTime &ts);

} // namespace ReportNaming
