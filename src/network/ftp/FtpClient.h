#pragma once
#include <QString>

// Minimal blocking FTP client.
//
// Qt 6 QNetworkAccessManager has no ftp:// backend
// ("Protocol ftp is unknown"), so report upload cannot go through QNAM.
// This client speaks plain FTP over QTcpSocket: login, binary mode,
// recursive MKD, passive-mode STOR. Every wait is bounded by m_timeoutMs,
// so it is safe to run on a worker thread (never on the UI thread).
class FtpClient {
public:
    explicit FtpClient(int timeoutMs = 30000);

    // Uploads localPath to remoteDir/fileName on host:port.
    // Missing remote directories are created (MKD -p semantics).
    // Returns true on success; otherwise false with *error set.
    bool upload(const QString &host, int port,
                const QString &username, const QString &password,
                const QString &remoteDir, const QString &localPath,
                QString *error = nullptr);

private:
    int m_timeoutMs;
};
