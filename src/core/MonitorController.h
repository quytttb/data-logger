#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QVariantList>
#include <QMutex>
#include <QHash>
#include <QQueue>
#include <deque>
#include <atomic>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

class MonitorModel;
class ModbusTcpServerService;
class DatabaseWorker;
struct AppConfig;
struct Sensor;
struct AnalogDigitalLink;

// Orchestrates ModbusWorker + DatabaseWorker threads and feeds MonitorModel.
class MonitorController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool   isPolling        READ isPolling        NOTIFY pollingChanged)
    Q_PROPERTY(bool   isStopping       READ isStopping       NOTIFY stoppingChanged)
    Q_PROPERTY(QString statusText      READ statusText       NOTIFY statusChanged)
    Q_PROPERTY(int    statusMode       READ statusMode       NOTIFY statusChanged)
    Q_PROPERTY(int    errorCount       READ errorCount       NOTIFY errorCountChanged)
    Q_PROPERTY(bool   hasActiveSensors READ hasActiveSensors NOTIFY activeSensorsChanged)
    Q_PROPERTY(QVariantList diLegend   READ diLegend         NOTIFY diLegendChanged)
    Q_PROPERTY(QVariantList analogSensors READ analogSensors NOTIFY analogSensorsListChanged)
    Q_PROPERTY(float  cpuTemp         READ cpuTemp          NOTIFY cpuTempChanged)
    Q_PROPERTY(QString watchdogStatus  READ watchdogStatus   NOTIFY watchdogChanged)

public:
    static constexpr int STATUS_IDLE = 0;
    static constexpr int STATUS_OK   = 1;
    static constexpr int STATUS_ERR  = 2;

    explicit MonitorController(MonitorModel *model,
                                ModbusTcpServerService *modbusTcp = nullptr,
                                QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(MonitorController)

    bool   isPolling()        const { return m_isPolling; }
    bool   isStopping()       const { return m_isStopping; }
    bool   rtuConnected()     const { return m_rtuConnected.load(); }
    QString statusText()      const;
    int    statusMode()       const { return m_statusMode; }
    int    errorCount()       const { return m_errorCount; }
    bool   hasActiveSensors() const;
    QVariantList diLegend()   const { return m_diLegend; }
    QVariantList analogSensors() const { return m_analogSensors; }
    float  cpuTemp()          const { return m_cpuTemp; }
    QString watchdogStatus()  const { return m_watchdogStatus; }

    // REST snapshot (called from network thread)
    QVariantMap readingsSnapshot() const;

    Q_INVOKABLE QVariantList getTrendBuffer(int sensorId) const;

public slots:
    void startPolling();
    void stopPolling();
    void stopPollingSync();
    void refreshSensors();
    // Overload: accepts pre-built sensor maps from SensorListModel to skip
    // a redundant DB read (called from main.cpp after each model reset).
    void refreshSensorsFromList(const QList<QVariantMap> &maps);
    void registerHeartbeat(const QString &workerName);
    void writeDo(int sensorId, bool value);

signals:
    void pollingChanged();
    void stoppingChanged();
    void statusChanged();
    void errorCountChanged();
    void activeSensorsChanged();
    void diLegendChanged();
    void analogSensorsListChanged();
    void cpuTempChanged();
    void watchdogChanged();
    void watchdogAlert(QString message);
    void messageSent(QString title, QString body);
    void recordsCommitted(int count);
    // Realtime trending signals
    void newDataPoint(int sensorId, double timestampMs, double value);

private slots:
    void onDataReady(QVariantMap payload);
    void onModbusError(QString msg);
    void onConnectionChanged(bool connected);
    void onModbusStopped();
    void onDbError(QString msg);
    void onRecordsSaved(int count);
    void onAlarmChanged(QVariantMap info);
    void readCpuTemp();
    void checkWatchdog();
    void checkThreadsFinished();

private:
    // startPolling() helpers — split out for readability.
    void buildPollSensors(const QList<Sensor> &allSensors,
                          const QList<AnalogDigitalLink> &allLinks,
                          QList<QVariantMap> &pollSensors,
                          QHash<int, QList<QVariantMap>> &digitalIoMap);
    void configureMbtcp(const QList<Sensor> &allSensors);
    void startWorkerThreads(const AppConfig &cfg,
                            const QList<QVariantMap> &pollSensors,
                            const QHash<int, QList<QVariantMap>> &digitalIoMap);

    void finalizeStop();
    void applyStatus(const QString &tag, int mode = -1);
    void resetTrendBuffers(const QList<QVariantMap> &sensors);
    void pushTrendPoint(int sensorId, const QString &recordedAt, double value);
    void buildDiLegend(const QList<QVariantMap> &diSensors,
                       const QList<QVariantMap> &links);
    void syncLinkedDigitalCards(const QVariantMap &payload);
    void cacheReading(const QVariantMap &payload);
    void markReadingsCacheErr();
    void clearReadingsCache();

    MonitorModel            *m_model;
    ModbusTcpServerService  *m_mbtcp;

    QThread        *m_modbusThread = nullptr;
    QThread        *m_dbThread     = nullptr;
    QObject        *m_modbusWorker = nullptr;
    DatabaseWorker *m_dbWorker     = nullptr;

    std::atomic<bool> m_isPolling          {false};
    std::atomic<bool> m_rtuConnected       {false};
    bool              m_isStopping        = false;
    bool              m_recoveryInProgress = false;
    int      m_statusMode = STATUS_IDLE;
    int      m_errorCount = 0;          // cumulative Modbus errors since polling started (UI badge)
    int      m_consecutiveErrors = 0;   // back-to-back errors; reset on any successful read
    QString  m_statusTag  = "ready";
    float    m_cpuTemp    = 0.0f;
    QString  m_watchdogStatus = "N/A";

    QVariantList m_diLegend;
    QHash<QString, QString> m_diLabelToColor;
    QVariantList m_analogSensors;

    // Trend buffers: sensor_id → circular deque of (timestamp_ms, value)
    static constexpr int kTrendBufferSize = 2000;
    QHash<int, std::deque<std::pair<double,double>>> m_trendBuffers;

    // REST readings cache
    mutable QMutex           m_readingsMutex;
    QHash<int, QVariantMap>  m_readingsCache;

    // Watchdog
    QTimer *m_watchdogTimer = nullptr;
    QTimer *m_cpuTimer      = nullptr;
    struct HeartbeatState { int misses = 0; double lastTime = 0; };
    QHash<QString, HeartbeatState> m_heartbeats;
};
