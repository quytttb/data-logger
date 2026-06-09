#pragma once
#include <QObject>
#include <QTimer>
#include <QNetworkAccessManager>

// Picks up pending report files from the ReportLog table and uploads them
// to the configured FTP / SFTP server. Mirrors Python workers/ftp_worker.py.
// Full SFTP support requires an external library (libssh2 / QSsh); for now
// the class handles plain FTP via QNetworkAccessManager and stubs SFTP.
class FtpWorker : public QObject {
    Q_OBJECT

public:
    explicit FtpWorker(QObject *parent = nullptr);

    void configure(const QString &address, int port,
                   const QString &username, const QString &password,
                   const QString &remotePath, const QString &protocol);

public slots:
    void start();
    void stop();

signals:
    void workerHeartbeat(QString workerName);
    void uploadSuccess(QString localPath, QString remotePath);
    void uploadFailed(QString localPath, QString error);
    void workerStopped();

private slots:
    void tick();
    void onHeartbeat();

private:
    bool uploadFile(const QString &localPath, const QString &remoteDir);

    QTimer *m_tickTimer = nullptr;
    QTimer *m_heartbeatTimer = nullptr;
    QNetworkAccessManager *m_nam = nullptr;

    QString m_address;
    int     m_port = 21;
    QString m_username;
    QString m_password;
    QString m_remotePath;
    QString m_protocol = "ftp";
    bool    m_running = false;
};
