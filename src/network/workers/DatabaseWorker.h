#pragma once
#include <QObject>
#include <QTimer>
#include <QQueue>
#include <QMutex>
#include <QVariantMap>

// Batches sensor readings and flushes to SQLite on a dedicated thread.
class DatabaseWorker : public QObject {
    Q_OBJECT

public:
    explicit DatabaseWorker(QObject *parent = nullptr);

    // Thread-safe: called from main thread to enqueue a data payload.
    void enqueue(const QVariantMap &payload);

public slots:
    void start();
    void stop();

signals:
    void recordsSaved(int count);
    void dbError(QString message);
    void workerStopped();
    void heartbeat(QString workerName);

private slots:
    void flush();
    void onHeartbeatTimer();

private:
    QTimer  *m_flushTimer = nullptr;
    QTimer  *m_heartbeatTimer = nullptr;
    QQueue<QVariantMap> m_queue;
    QMutex   m_mutex;
    bool     m_running = false;

    static constexpr int kFlushIntervalMs = 1000;
};
