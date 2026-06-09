#include "FtpWorker.h"
#include "../core/Database.h"
#include "../core/dao/ReportLogDao.h"
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
                           const QString &remotePath, const QString &protocol) {
    m_address    = address;
    m_port       = port;
    m_username   = username;
    m_password   = password;
    m_remotePath = remotePath;
    m_protocol   = protocol.toLower();
}

void FtpWorker::start() {
    m_running = true;
    m_nam = new QNetworkAccessManager(this);

    m_tickTimer = new QTimer(this);
    m_tickTimer->setInterval(60 * 1000); // check every minute
    connect(m_tickTimer, &QTimer::timeout, this, &FtpWorker::tick);
    m_tickTimer->start();

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(30 * 1000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &FtpWorker::onHeartbeat);
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

    auto db = Database::openConnection();
    if (!db.isOpen()) return;

    ReportLogDao dao(db);
    auto pending = dao.loadPending(5);
    db.close();

    for (auto &log : pending) {
        if (!m_running) break;
        if (uploadFile(log.filePath, m_remotePath)) {
            auto db2 = Database::openConnection();
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "success");
            db2.close();
            emit uploadSuccess(log.filePath, m_remotePath);
        } else {
            auto db2 = Database::openConnection();
            ReportLogDao dao2(db2);
            dao2.updateStatus(log.id, "failed", log.retryCount + 1);
            db2.close();
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
    QString scheme = (m_protocol == "ftp") ? "ftp" : "ftp"; // SFTP requires external lib
    QUrl url;
    url.setScheme(scheme);
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
