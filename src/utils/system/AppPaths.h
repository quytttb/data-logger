#pragma once
#include <QString>
#include <QDir>

namespace AppPaths {

QString dataDir();
QString configDir();
QString logDir();
QString appIconPath();

void ensureDirectories();

} // namespace AppPaths
