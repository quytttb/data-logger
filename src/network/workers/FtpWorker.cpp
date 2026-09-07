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
    m_address    = address;
    m_port       = port;
    m_username   = username;
    m_password   = password;
    m_remotePath = remotePath;
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
    if (!m_running || m_address.isEmpty()) return;

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
        if (uploadFile(log.filePath, log.remotePath.isEmpty() ? m_remotePath : log.remotePath, &error)) {
            ScopedDbConnection db2;
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "success");
            emit uploadSuccess(log.filePath, log.remotePath.isEmpty() ? m_remotePath : log.remotePath);
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
    if (client.upload(m_address, m_port > 0 ? m_port : kDefaultPort,
                      m_username, m_password, dir, localPath, &clientError)) {
        return true;
    }
    if (error)
        *error = clientError;
    return false;
}
