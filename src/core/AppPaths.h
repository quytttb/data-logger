#pragma once
#include <QString>
#include <QStandardPaths>
#include <QDir>
#include <QCoreApplication>

// Centralised path resolution (mirrors Python core/_paths.py).
// All paths are resolved relative to the application binary directory,
// but can be overridden via environment variables for deployment flexibility.
namespace AppPaths {

QString rootDir();
QString dataDir();
QString configDir();
QString logDir();
QString qmlDir();
QString appIconPath();          // Returns best available icon (PNG > SVG) or ""

constexpr const char* APP_DESKTOP_ID = "data-logger";

// Ensure all required runtime directories exist
void ensureDirectories();

} // namespace AppPaths
