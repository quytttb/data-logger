#include "FtpWorker.h"
#include "data/db/Database.h"
#include "data/repositories/ReportLogDao.h"
#include "network/ftp/FtpClient.h"
#include <QFile>
#include <QDebug>

namespace {
constexpr int kTickIntervalMs      = 60 * 1000;  // scan pending reports each minute
constexpr int kHeartbeatIntervalMs = 30 * 1000;  // liveness ping to MonitorController
constexpr int kUploadTimeoutMs     = 2 * 60 * 1000; // H-2: không treo worker vô hạn khi FTP server im lặng
}

FtpWorker::FtpWorker(QObject *parent) : QObject(parent) {}

void FtpWorker::configure(const QString &address, int port,
                           const QString &username, const QString &password,
                           const QString &remotePath) {
    QMutexLocker lock(&m_cfgMutex);
    m_address    = address;
    m_port       = port;
    m_username   = username;
    m_password   = password;
    m_remotePath = remotePath;
}

void FtpWorker::snapshotConfig(QString *address, int *port, QString *user,
                               QString *pass, QString *remotePath) {
    QMutexLocker lock(&m_cfgMutex);
    if (address)    *address    = m_address;
    if (port)       *port       = m_port;
    if (user)       *user       = m_username;
    if (pass)       *pass       = m_password;
    if (remotePath) *remotePath = m_remotePath;
}

void FtpWorker::start() {
    if (m_running) return;
    m_running = true;

    if (!m_tickTimer) {
        m_tickTimer = new QTimer(this);
        m_tickTimer->setInterval(kTickIntervalMs);
        connect(m_tickTimer, &QTimer::timeout, this, &FtpWorker::tick);
    }
    m_tickTimer->start();

    if (!m_heartbeatTimer) {
        m_heartbeatTimer = new QTimer(this);
        m_heartbeatTimer->setInterval(kHeartbeatIntervalMs);
        connect(m_heartbeatTimer, &QTimer::timeout, this, &FtpWorker::onHeartbeat);
    }
    m_heartbeatTimer->start();

    tick(); // immediate first attempt
}

void FtpWorker::stop() {
    m_running = false;
    if (m_tickTimer)      m_tickTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();

    emit workerStopped();
}

void FtpWorker::onHeartbeat() {
    if (m_running) emit workerHeartbeat("FtpWorker");
}

void FtpWorker::tick() {
    if (!m_running)
        return;
    QString cfgAddr, cfgUser, cfgPass, cfgRemote;
    int cfgPort = kDefaultPort;
    snapshotConfig(&cfgAddr, &cfgPort, &cfgUser, &cfgPass, &cfgRemote);
    if (cfgAddr.isEmpty()) return;

    QList<ReportLog> pending;
    {
        ScopedDbConnection db;
        if (!db.get().isOpen())
            return;
        ReportLogDao dao(db);
        pending = dao.loadPending(5);
    }

    for (auto &log : pending) {
        if (!m_running) break;
        QString error;
        if (uploadFile(log.filePath, log.remotePath.isEmpty() ? cfgRemote : log.remotePath, &error)) {
            ScopedDbConnection db2;
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "success");
            emit uploadSuccess(log.filePath, log.remotePath.isEmpty() ? cfgRemote : log.remotePath);
        } else {
            ScopedDbConnection db2;
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "failed", log.retryCount + 1);
            qWarning().noquote() << QStringLiteral("FtpWorker upload error: %1 (%2)")
                                        .arg(log.filePath, error);
            emit uploadFailed(log.filePath, error);
        }
    }
}

bool FtpWorker::uploadFile(const QString &localPath, const QString &remoteDir, QString *error) {
    if (!QFile::exists(localPath)) {
        if (error)
            *error = QStringLiteral("local file missing: ") + localPath;
        return false;
    }

    // H-2 fix: ghép path an toàn — remoteDir có thể kết thúc bằng '/' khiến
    // path ra "dir//file" (một số FTP server từ chối).
    QString dir = remoteDir;
    while (dir.endsWith(QLatin1Char('/')) && dir.size() > 1)
        dir.chop(1);

    FtpClient client(kUploadTimeoutMs);
    QString clientError;
    QString snapAddr, snapUser, snapPass;
    int snapPort = kDefaultPort;
    snapshotConfig(&snapAddr, &snapPort, &snapUser, &snapPass, nullptr);
    if (client.upload(snapAddr, snapPort > 0 ? snapPort : kDefaultPort,
                      snapUser, snapPass, dir, localPath, &clientError)) {
        return true;
    }
    if (error)
        *error = clientError;
    return false;
}
