#include "ReportController.h"
#include "SettingsController.h"
#include "network/workers/FtpWorker.h"
#include "utils/AppPaths.h"
#include "utils/Crypto.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/SensorDataDao.h"
#include "data/repositories/ReportLogDao.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <algorithm>

static ReportController *g_reportInstance = nullptr;

ReportController *ReportController::instance() { return g_reportInstance; }

void ReportController::setInstance(ReportController *controller)
{
    g_reportInstance = controller;
}

ReportController *ReportController::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(g_reportInstance);
    QQmlEngine::setObjectOwnership(g_reportInstance, QQmlEngine::CppOwnership);
    return g_reportInstance;
}

ReportController::ReportController(QObject *parent) : QObject(parent)
{
    m_scheduleTimer = new QTimer(this);
    m_scheduleTimer->setInterval(60 * 1000);
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
    auto db = Database::openConnection();
    ReportLogDao dao(db);
    m_pendingCount = dao.loadPending(1000).size();
    db.close();
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
        m_ftpWorker->stop();
        setRunning(false);
        setLastStatus(QStringLiteral("Stopped"));
        refreshStatus();
        return;
    }

    const QString password = cfg.ftpPassword.isEmpty()
        ? QString()
        : Crypto::decrypt(cfg.ftpPassword);
    QString protocol = cfg.ftpProtocol.trimmed().toLower();
    if (protocol.isEmpty())
        protocol = QStringLiteral("ftp");

    m_ftpWorker->configure(cfg.ftpAddress, cfg.ftpPort, cfg.ftpUsername,
                           password, cfg.ftpRemotePath, protocol);
    m_ftpWorker->start();
    setRunning(true);
    setLastStatus(protocol == QStringLiteral("sftp")
                      ? QStringLiteral("Running (SFTP not supported — using FTP)")
                      : QStringLiteral("Running"));
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

    const QDateTime to = now;
    const QDateTime from = to.addSecs(-cfg.serverSendInterval * 60);
    generateReport(from, to);
    s_lastGenerated = now;
}

void ReportController::generateReport(const QDateTime &from, const QDateTime &to) {
    auto db = Database::openConnection();
    SensorDao sDao(db);
    SensorDataDao sdDao(db);
    ReportLogDao logDao(db);

    auto sensors = sDao.loadAll(true);

    std::sort(sensors.begin(), sensors.end(),
              [](const Sensor &a, const Sensor &b){ return a.reportIndex < b.reportIndex; });

    QString fname = from.toString("yyyyMMdd_HHmmss") + ".txt";
    QDir().mkpath(AppPaths::dataDir());
    QString path = AppPaths::dataDir() + "/" + fname;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit messageSent("Error", "Cannot write report file: " + path);
        db.close();
        return;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    out << "Thoi gian: " << from.toString("dd/MM/yyyy HH:mm:ss")
        << " - " << to.toString("dd/MM/yyyy HH:mm:ss") << "\n";
    out << "STT";
    for (const auto &s : sensors)
        out << "\t" << s.name + " (" + s.unit + ")";
    out << "\n";

    QDateTime cursor = from;
    int row = 1;
    while (cursor <= to) {
        QDateTime next = cursor.addSecs(60);
        out << row++;
        for (const auto &s : sensors) {
            auto data = sdDao.query(s.id, cursor, next, 60);
            if (data.isEmpty()) { out << "\t---"; continue; }
            double sum = 0; int cnt = 0;
            for (const auto &d : data)
                if (d.value.has_value()) { sum += *d.value; ++cnt; }
            if (cnt > 0) out << "\t" << QString::number(sum/cnt, 'f', 4);
            else          out << "\t---";
        }
        out << "\n";
        cursor = next;
    }
    file.close();

    ReportLog log;
    log.filePath = path;
    logDao.insert(log);
    db.close();

    refreshStatus();
    emit reportGenerated(path);
    emit messageSent("Success", "Report saved: " + fname);
}
