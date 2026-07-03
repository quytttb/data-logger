#pragma once
#include "data/models/AppConfig.h"
#include <QDateTime>
#include <QString>

namespace ReportNaming {

QString buildFileName(const AppConfig &cfg, const QDateTime &ts);
QString buildRemoteDir(const AppConfig &cfg, const QDateTime &ts);

} // namespace ReportNaming
