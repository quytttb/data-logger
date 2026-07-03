#include "ReportController.h"
#include "SettingsController.h"
#include "network/workers/FtpWorker.h"
#include "utils/system/AppPaths.h"
#include "utils/crypto/Crypto.h"
#include "utils/tt10/ReportNaming.h"
#include "tt10/Tt10ReportWriter.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/SensorDataDao.h"
#include "data/repositories/ReportLogDao.h"
#include "data/repositories/AppConfigDao.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <QThreadPool>
#include <algorithm>

IMPLEMENT_QML_SINGLETON(ReportController)

namespace {
constexpr int kScheduleTickMs = 60 * 1000;  // report scheduler tick (1 min)
}

ReportController::ReportController(QObject *parent) : QObject(parent)
{
    m_scheduleTimer = new QTimer(this);
    m_scheduleTimer->setInterval(kScheduleTickMs);
    connect(m_scheduleTimer, &QTimer::timeout, this, &ReportController::onScheduleTick);
    m_scheduleTimer->start();
}

void ReportController::setFtpWorker(FtpWorker *worker)
{
    if (m_ftpWorker == worker)
        return;
    if (m_ftpWorker) {
        disconnect(m_ftpWorker, nullptr, this, nullptr);
    }
    m_ftpWorker = worker;
    if (m_ftpWorker) {
        connect(m_ftpWorker, &FtpWorker::uploadSuccess,
                this, &ReportController::onUploadSuccess);
        connect(m_ftpWorker, &FtpWorker::uploadFailed,
                this, &ReportController::onUploadFailed);
        connect(m_ftpWorker, &FtpWorker::workerStopped,
                this, &ReportController::onFtpStopped);
    }
    refreshStatus();
}

void ReportController::setSettingsController(SettingsController *settings)
{
    if (m_settings == settings)
        return;
    if (m_settings) {
        disconnect(m_settings, nullptr, this, nullptr);
    }
    m_settings = settings;
    if (m_settings) {
        connect(m_settings, &SettingsController::configSaved,
                this, &ReportController::applyServerConfig);
        connect(m_settings, &SettingsController::serverActiveChanged, this, [this]() {
            if (m_settings && !m_settings->serverActive())
                applyServerConfig();
        });
    }
}

void ReportController::setRunning(bool v)
{
    if (m_isRunning == v)
        return;
    m_isRunning = v;
    emit statusChanged();
}

void ReportController::setLastStatus(const QString &s)
{
    if (m_lastStatus == s)
        return;
    m_lastStatus = s;
    emit statusChanged();
}

void ReportController::refreshStatus()
{
    {
        ScopedDbConnection db;
        ReportLogDao dao(db);
        m_pendingCount = dao.loadPending(1000).size();
    }
    setRunning(m_ftpWorker != nullptr && m_settings && m_settings->serverActive());
    if (m_pendingCount > 0 && m_lastStatus == QStringLiteral("Idle"))
        setLastStatus(QStringLiteral("Pending upload"));
    emit statusChanged();
}

void ReportController::applyServerConfig()
{
    if (!m_ftpWorker || !m_settings)
        return;

    const AppConfig &cfg = m_settings->config();

    if (!cfg.serverActive || cfg.ftpAddress.trimmed().isEmpty()) {
        QMetaObject::invokeMethod(m_ftpWorker, "stop", Qt::BlockingQueuedConnection);
        setRunning(false);
        setLastStatus(QStringLiteral("Stopped"));
        refreshStatus();
        return;
    }

    const QString password = cfg.ftpPassword.isEmpty()
        ? QString()
        : Crypto::decrypt(cfg.ftpPassword);

    // Stop worker first so configure() is safe (worker not in tick())
    QMetaObject::invokeMethod(m_ftpWorker, "stop", Qt::BlockingQueuedConnection);
    m_ftpWorker->configure(cfg.ftpAddress, cfg.ftpPort, cfg.ftpUsername,
                           password, cfg.ftpRemotePath);
    QMetaObject::invokeMethod(m_ftpWorker, "start", Qt::QueuedConnection);
    setRunning(true);
    setLastStatus(QStringLiteral("Running"));
    refreshStatus();
}

void ReportController::onUploadSuccess(const QString &localPath, const QString &remotePath)
{
    Q_UNUSED(localPath)
    Q_UNUSED(remotePath)
    setLastStatus(QStringLiteral("OK"));
    refreshStatus();
}

void ReportController::onUploadFailed(const QString &localPath, const QString &error)
{
    Q_UNUSED(localPath)
    setLastStatus(error.isEmpty() ? QStringLiteral("Upload failed") : error);
    refreshStatus();
}

void ReportController::onFtpStopped()
{
    setRunning(false);
    setLastStatus(QStringLiteral("Stopped"));
    refreshStatus();
}

void ReportController::onScheduleTick()
{
    if (!m_settings)
        return;
    const AppConfig &cfg = m_settings->config();
    if (!cfg.serverActive || cfg.serverSendInterval <= 0)
        return;

    static QDateTime s_lastGenerated;
    const QDateTime now = QDateTime::currentDateTime();
    if (s_lastGenerated.isValid()
        && s_lastGenerated.secsTo(now) < cfg.serverSendInterval * 60)
        return;

    const QTime start = QTime::fromString(cfg.serverStartTime, QStringLiteral("HH:mm"));
    if (start.isValid()) {
        const QTime current = now.time();
        if (current < start)
            return;
    }

    const QDateTime to   = now;
    const QDateTime from = to.addSecs(-cfg.serverSendInterval * 60);
    s_lastGenerated = now;

    if (m_generating.load(std::memory_order_relaxed))
        return; // previous report still in progress

    m_generating.store(true, std::memory_order_relaxed);
    QThreadPool::globalInstance()->start([this, from, to]() {
        generateReport(from, to);
        m_generating.store(false, std::memory_order_relaxed);
    });
}

void ReportController::generateReport(const QDateTime &from, const QDateTime &to) {
    AppConfig cfg;
    {
        ScopedDbConnection db;
        cfg = AppConfigDao(db).load();
    }

    if (cfg.filePrefix.trimmed().isEmpty()) {
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("File prefix is not configured (TT10)."));
        return;
    }

    const QString fname = ReportNaming::buildFileName(cfg, to);
    QDir().mkpath(AppPaths::dataDir());
    const QString path = AppPaths::dataDir() + QLatin1Char('/') + fname;
    const QString remoteDir = ReportNaming::buildRemoteDir(cfg, to);

    {
        ScopedDbConnection db;
        SensorDao sDao(db);
        SensorDataDao sdDao(db);
        ReportLogDao logDao(db);

        auto sensors = sDao.loadAll(true);

        std::sort(sensors.begin(), sensors.end(),
                  [](const Sensor &a, const Sensor &b){ return a.reportIndex < b.reportIndex; });

        if (!Tt10ReportWriter::write(path, sensors, sdDao, from, to)) {
            emit messageSent(QStringLiteral("Error"),
                             QStringLiteral("Cannot write report file: ") + path);
            return;
        }

        ReportLog log;
        log.filePath = path;
        log.remotePath = remoteDir;
        logDao.insert(log);
    }

    refreshStatus();
    emit reportGenerated(path);
    emit messageSent(QStringLiteral("Success"), QStringLiteral("Report saved: ") + fname);
}
