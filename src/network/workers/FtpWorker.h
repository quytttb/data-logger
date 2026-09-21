#pragma once
#include <QObject>
#include <QTimer>
#include <QMutex>

// Picks up pending report files from the ReportLog table and uploads them
// Uploads generated report files to FTP on a schedule (via FtpClient —
// Qt 6 QNAM has no ftp:// backend).
class FtpWorker : public QObject {
    Q_OBJECT

public:
    explicit FtpWorker(QObject *parent = nullptr);

    // Thread-safe: configure có thể được gọi từ UI thread trong khi tick()
    // đang upload (FtpClient timeout 2 phút). Mọi truy cập config qua mutex.
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
    bool uploadFile(const QString &localPath, const QString &remoteDir,
                    QString *error = nullptr);
    void snapshotConfig(QString *address, int *port, QString *user,
                        QString *pass, QString *remotePath);

    QTimer *m_tickTimer = nullptr;
    QTimer *m_heartbeatTimer = nullptr;

    static constexpr int kDefaultPort = 21;  // FTP control port

    mutable QMutex m_cfgMutex;
    QString m_address;
    int     m_port = kDefaultPort;
    QString m_username;
    QString m_password;
    QString m_remotePath;
    bool    m_running = false;
};
