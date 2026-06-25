#include "LogSetup.h"
#include <QLoggingCategory>
#include <QFile>
#include <QDir>
#include <QString>
#include <QDateTime>
#include <QtDebug>
#include <mutex>

static QFile *g_logFile = nullptr;
static std::mutex g_logMutex;

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
        g_logFile->write(line.toUtf8());
        g_logFile->flush();
    }
    // Also write to stderr
    fprintf(stderr, "%s", qPrintable(line));
}

void setupLogging(const QString &logDir) {
    QDir().mkpath(logDir);
    QString path = logDir + "/datalogger-" + QDateTime::currentDateTime().toString("yyyyMMdd") + ".log";
    g_logFile = new QFile(path);
    if (!g_logFile->open(QIODevice::Append | QIODevice::Text)) {
        delete g_logFile; g_logFile = nullptr;
    }
    qInstallMessageHandler(messageHandler);
}
