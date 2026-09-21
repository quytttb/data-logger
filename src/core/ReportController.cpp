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
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDebug>
#include <QThread>
#include <QSemaphore>
#include <QQmlEngine>
#include <QJSEngine>
#include <QThreadPool>
#include <algorithm>

IMPLEMENT_QML_SINGLETON(ReportController)

namespace {
constexpr int kScheduleTickMs = 60 * 1000;  // report scheduler tick (1 min)
constexpr int kStopWorkerMs   = 5000;

bool stopFtpWorkerBounded(FtpWorker *worker, int timeoutMs) {
    if (!worker) return true;
    QThread *t = worker->thread();
    if (!t || !t->isRunning()) {
        QMetaObject::invokeMethod(worker, "stop", Qt::QueuedConnection);
        return true;
    }
    auto sem = std::make_shared<QSemaphore>();
    QMetaObject::invokeMethod(worker, "stop", Qt::QueuedConnection);
    QMetaObject::invokeMethod(worker, [sem]() { sem->release(); }, Qt::QueuedConnection);
    const bool done = sem->tryAcquire(1, timeoutMs);
    if (!done)
        qWarning() << "ReportController: FtpWorker stop did not complete within" << timeoutMs << "ms";
    return done;
}
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
    // Không subscribe configSaved ở đây — main.cpp đã là single owner gọi
    // applyServerConfig() qua applyConfig() lambda. Để ReportController cũng
    // subscribe sẽ gọi apply 2 lần mỗi lần Save (duplicate stop/configure/start).
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

void ReportController::setUploadState(UploadState s)
{
    if (m_uploadState == s)
        return;
    m_uploadState = s;
    emit statusChanged();
}

QString ReportController::previewRemotePath() const
{
    if (!m_settings)
        return {};
    return ReportNaming::buildPreviewPath(m_settings->config(),
                                          QDateTime::currentDateTime());
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
        stopFtpWorkerBounded(m_ftpWorker, kStopWorkerMs);
        setRunning(false);
        setUploadState(UploadStopped);
        setLastStatus(QStringLiteral("Stopped"));
        refreshStatus();
        return;
    }

    const QString password = cfg.ftpPassword.isEmpty()
        ? QString()
        : Crypto::decrypt(cfg.ftpPassword);

    // Reconfigure là data race nếu worker đang tick() upload (timeout 2 phút).
    // Trước đây configure() trực tiếp từ UI thread trong khi FtpWorker đọc
    // m_address/m_username... từ worker thread. Nay FtpWorker::configure()
    // đã lock mutex nên có thể configure ngay cả khi stop timeout, nhưng vẫn
    // phải ưu tiên stop thành công trước khi start lại.
    const bool stopped = stopFtpWorkerBounded(m_ftpWorker, kStopWorkerMs);
    // Configure qua queued invoke để không chạm object thuộc worker thread
    // trong khi queued stop() có thể vẫn đang chạy tail của tick().
    const QString addr = cfg.ftpAddress, user = cfg.ftpUsername, rpath = cfg.ftpRemotePath;
    const int port = cfg.ftpPort;
    QMetaObject::invokeMethod(m_ftpWorker, [w = m_ftpWorker, addr, port, user, password, rpath]() {
        w->configure(addr, port, user, password, rpath);
    }, Qt::QueuedConnection);
    QMetaObject::invokeMethod(m_ftpWorker, "start", Qt::QueuedConnection);
    if (!stopped) {
        qWarning() << "ReportController: reconfigured FtpWorker while previous stop timed out — config will take effect after current upload";
        setLastStatus(QStringLiteral("Reconfiguring…"));
    } else {
        setLastStatus(QStringLiteral("Running"));
    }
    setRunning(true);
    setUploadState(UploadRunning);
    refreshStatus();
}

void ReportController::onUploadSuccess(const QString &localPath, const QString &remotePath)
{
    Q_UNUSED(localPath)
    Q_UNUSED(remotePath)
    setUploadState(UploadOk);
    setLastStatus(QStringLiteral("OK"));
    refreshStatus();
}

void ReportController::onUploadFailed(const QString &localPath, const QString &error)
{
    Q_UNUSED(localPath)
    setUploadState(UploadFailed);
    setLastStatus(error.isEmpty() ? QStringLiteral("Upload failed") : error);
    refreshStatus();
}

void ReportController::onFtpStopped()
{
    setRunning(false);
    setUploadState(UploadStopped);
    setLastStatus(QStringLiteral("Stopped"));
    refreshStatus();
}

void ReportController::onScheduleTick()
{
    if (!m_settings)
        return;
    // Single source of truth: snapshot the in-memory config once here and
    // hand it to the worker thread — no second DB read inside generation.
    const AppConfig cfg = m_settings->config();
    if (!cfg.serverActive || cfg.serverSendInterval <= 0)
        return;

    const QDateTime now = QDateTime::currentDateTime();
    if (m_lastGenerated.isValid()
        && m_lastGenerated.secsTo(now) < cfg.serverSendInterval * 60)
        return;

    const QTime start = QTime::fromString(cfg.serverStartTime, QStringLiteral("HH:mm"));
    if (start.isValid()) {
        const QTime current = now.time();
        if (current < start)
            return;
    }

    // H-6 fix: mốc "sinh gần nhất" được persist trong report_log — khởi động
    // lại không làm mất/overlap cửa sổ báo cáo (trước đây dùng biến static).
    QDateTime from = now.addSecs(-cfg.serverSendInterval * 60);
    if (!m_lastGenerated.isValid()) {
        const QDateTime persisted = [this]() {
            ScopedDbConnection db;
            return ReportLogDao(db).lastGeneratedAt();
        }();
        if (persisted.isValid() && persisted > from && persisted < now)
            from = persisted;
    }
    const QDateTime to = now;
    m_lastGenerated = now;

    if (m_generating.load(std::memory_order_relaxed))
        return; // previous report still in progress

    m_generating.store(true, std::memory_order_relaxed);
    QThreadPool::globalInstance()->start([this, from, to, cfg]() {
        runReportGeneration(from, to, cfg);
        m_generating.store(false, std::memory_order_relaxed);
    });
}

void ReportController::generateReport(const QDateTime &from, const QDateTime &to) {
    if (!m_settings)
        return;
    runReportGeneration(from, to, m_settings->config());
}

void ReportController::runReportGeneration(const QDateTime &from, const QDateTime &to,
                                           const AppConfig &cfg) {

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
    // No success toast: scheduled transmission must run silently and only
    // surface errors (messageSent Error paths below stay as-is).
}
