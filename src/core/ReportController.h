#pragma once
#include <QObject>
#include <QString>
#include <QDateTime>
#include <QTimer>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;
class FtpWorker;
class SettingsController;

// Generates TXT report files (Phụ lục 15 format) and logs them for FTP.
class ReportController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY statusChanged)
    Q_PROPERTY(QString lastStatus READ lastStatus NOTIFY statusChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY statusChanged)

public:
    explicit ReportController(QObject *parent);

    static ReportController *instance();
    static void setInstance(ReportController *controller);
    static ReportController *create(QQmlEngine *, QJSEngine *);

    bool isRunning() const { return m_isRunning; }
    QString lastStatus() const { return m_lastStatus; }
    int pendingCount() const { return m_pendingCount; }

    void setFtpWorker(FtpWorker *worker);
    void setSettingsController(SettingsController *settings);

public slots:
    Q_INVOKABLE void generateReport(const QDateTime &from, const QDateTime &to);
    void refreshStatus();
    void applyServerConfig();

signals:
    void messageSent(QString title, QString body);
    void reportGenerated(QString filePath);
    void statusChanged();

private slots:
    void onUploadSuccess(const QString &localPath, const QString &remotePath);
    void onUploadFailed(const QString &localPath, const QString &error);
    void onFtpStopped();
    void onScheduleTick();

private:
    void setRunning(bool v);
    void setLastStatus(const QString &s);

    FtpWorker          *m_ftpWorker = nullptr;
    SettingsController *m_settings  = nullptr;
    QTimer             *m_scheduleTimer = nullptr;
    bool                m_isRunning = false;
    QString             m_lastStatus = QStringLiteral("Idle");
    int                 m_pendingCount = 0;
};
