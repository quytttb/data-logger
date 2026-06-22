#include "FtpWorker.h"
#include "data/db/Database.h"
#include "data/repositories/ReportLogDao.h"
#include <QFile>
#include <QFileInfo>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QUrl>
#include <QDebug>

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

    if (!m_nam)
        m_nam = new QNetworkAccessManager(this);

    if (!m_tickTimer) {
        m_tickTimer = new QTimer(this);
        m_tickTimer->setInterval(60 * 1000);
        connect(m_tickTimer, &QTimer::timeout, this, &FtpWorker::tick);
    }
    m_tickTimer->start();

    if (!m_heartbeatTimer) {
        m_heartbeatTimer = new QTimer(this);
        m_heartbeatTimer->setInterval(30 * 1000);
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
        if (uploadFile(log.filePath, m_remotePath)) {
            ScopedDbConnection db2;
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "success");
            emit uploadSuccess(log.filePath, m_remotePath);
        } else {
            ScopedDbConnection db2;
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "failed", log.retryCount + 1);
            emit uploadFailed(log.filePath, "upload failed");
        }
    }
}

bool FtpWorker::uploadFile(const QString &localPath, const QString &remoteDir) {
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "FtpWorker: cannot open" << localPath;
        return false;
    }

    QFileInfo fi(localPath);
    QUrl url;
    url.setScheme(QStringLiteral("ftp"));
    url.setHost(m_address);
    url.setPort(m_port);
    url.setUserName(m_username);
    url.setPassword(m_password);
    url.setPath(remoteDir + "/" + fi.fileName());

    QNetworkRequest req(url);
    QNetworkReply *reply = m_nam->put(req, &file);

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    bool ok = (reply->error() == QNetworkReply::NoError);
    if (!ok) qWarning() << "FtpWorker upload error:" << reply->errorString();
    reply->deleteLater();
    file.close();
    return ok;
}
