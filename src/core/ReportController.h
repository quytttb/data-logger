#pragma once
#include <QObject>
#include <QString>
#include <QDateTime>
#include <QTimer>
#include <atomic>
#include <QtQmlIntegration/qqmlintegration.h>
#include "data/models/AppConfig.h"
#include "utils/qml/QmlSingleton.h"

class FtpWorker;
class SettingsController;

// Generates TXT report files (Phụ lục 15 format) and logs them for FTP.
class ReportController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY statusChanged)
    Q_PROPERTY(UploadState uploadState READ uploadState NOTIFY statusChanged)
    Q_PROPERTY(QString lastStatus READ lastStatus NOTIFY statusChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY statusChanged)

public:
    // Upload health for the sidebar dot — replaces lastStatus
    // string-matching ("FAIL"/"ERROR"/"OK") in QML.
    enum UploadState { UploadStopped, UploadRunning, UploadOk, UploadFailed };
    Q_ENUM(UploadState)
    explicit ReportController(QObject *parent);

    DECLARE_QML_SINGLETON(ReportController)

    bool isRunning() const { return m_isRunning; }
    UploadState uploadState() const { return m_uploadState; }
    QString lastStatus() const { return m_lastStatus; }
    int pendingCount() const { return m_pendingCount; }

    void setFtpWorker(FtpWorker *worker);
    void setSettingsController(SettingsController *settings);

public slots:
    Q_INVOKABLE void generateReport(const QDateTime &from, const QDateTime &to);
    // Live "dir + file" preview for Settings (reads the in-memory config so
    // keystrokes reflect immediately, before Save).
    Q_INVOKABLE QString previewRemotePath() const;
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
    void setUploadState(UploadState s);
    // Worker-thread report generation with an explicit config snapshot —
    // single source of truth captured on the UI thread (no second DB read).
    void runReportGeneration(const QDateTime &from, const QDateTime &to,
                             const AppConfig &cfg);

    FtpWorker          *m_ftpWorker = nullptr;
    SettingsController *m_settings  = nullptr;
    QTimer *m_scheduleTimer = nullptr;
    bool                m_isRunning = false;
    UploadState         m_uploadState = UploadStopped;
    QString             m_lastStatus = QStringLiteral("Idle");
    int                 m_pendingCount = 0;
    std::atomic<bool>   m_generating {false};
    // H-6: thời điểm sinh báo cáo gần nhất (in-memory; mốc khởi động lại được
    // khôi phục từ report_log qua ReportLogDao::lastGeneratedAt()).
    QDateTime           m_lastGenerated;
};
