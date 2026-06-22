#pragma once
#include <QObject>
#include <QTimer>
#include <QNetworkAccessManager>

// Picks up pending report files from the ReportLog table and uploads them
// Uploads generated report files to FTP on a schedule.
class FtpWorker : public QObject {
    Q_OBJECT

public:
    explicit FtpWorker(QObject *parent = nullptr);

    void configure(const QString &address, int port,
                   const QString &username, const QString &password,
                   const QString &remotePath);

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
    bool    m_running = false;
};
