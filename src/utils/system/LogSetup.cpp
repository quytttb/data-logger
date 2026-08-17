#include "LogSetup.h"
#include <QLoggingCategory>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QString>
#include <QDateTime>
#include <QtDebug>
#include <mutex>

namespace {
// Audit H7/P2-19: rotate during the run (not only at startup) so a 24/7
// kiosk session cannot grow the log file without bound. Keep kKeepBackups
// rotated copies per day file.
constexpr qint64 kMaxLogBytes = 2 * 1024 * 1024; // 2 MB per file
constexpr int    kKeepBackups = 5;
} // namespace

static QFile *g_logFile = nullptr;
static QString g_logBase; // path without the ".log" suffix (for rotation)
static std::mutex g_logMutex;

// Rotate the current log: app.log → .1 → .2 … → .kKeepBackups (oldest dropped).
static void rotateLocked() {
    if (!g_logFile) return;
    g_logFile->close();
    QFile::remove(g_logBase + QStringLiteral(".%1.log").arg(kKeepBackups));
    for (int i = kKeepBackups - 1; i >= 1; --i)
        QFile::rename(g_logBase + QStringLiteral(".%1.log").arg(i),
                      g_logBase + QStringLiteral(".%1.log").arg(i + 1));
    QFile::rename(g_logBase + QStringLiteral(".log"),
                  g_logBase + QStringLiteral(".1.log"));
    if (g_logFile->open(QIODevice::Append | QIODevice::Text)) return;
    delete g_logFile;
    g_logFile = nullptr; // unrotatable — keep stderr only
}

static void messageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
    Q_UNUSED(ctx)
    const char *level = "DEBUG";
    switch (type) {
    case QtInfoMsg:     level = "INFO";  break;
    case QtWarningMsg:  level = "WARN";  break;
    case QtCriticalMsg: level = "ERROR"; break;
    case QtFatalMsg:    level = "FATAL"; break;
    default: break;
    }
    QString line = QStringLiteral("[%1] %2: %3\n")
                   .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz"))
                   .arg(level).arg(msg);

    std::lock_guard<std::mutex> lk(g_logMutex);
    if (g_logFile && g_logFile->isOpen()) {
        if (g_logFile->size() + line.size() > kMaxLogBytes) rotateLocked();
        if (g_logFile && g_logFile->isOpen()) {
            g_logFile->write(line.toUtf8());
            g_logFile->flush();
        }
    }
    // Also write to stderr
    fprintf(stderr, "%s", qPrintable(line));
}

void setupLogging(const QString &logDir) {
    QDir().mkpath(logDir);
    const QString base = logDir + QStringLiteral("/datalogger-")
                       + QDateTime::currentDateTime().toString("yyyyMMdd");
    g_logBase = base;
    const QString path = base + QStringLiteral(".log");

    g_logFile = new QFile(path);
    if (!g_logFile->open(QIODevice::Append | QIODevice::Text)) {
        delete g_logFile; g_logFile = nullptr;
    } else if (g_logFile->size() > kMaxLogBytes) {
        rotateLocked(); // oversized leftover from a previous run
    }
    qInstallMessageHandler(messageHandler);
}
