#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QVariantList>
#include <QMutex>
#include <QHash>
#include <QSet>
#include <QQueue>
#include <QPointer>
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
    Q_PROPERTY(bool   isRetrying       READ isRetrying       NOTIFY retryStateChanged)
    Q_PROPERTY(QString statusText      READ statusText       NOTIFY statusChanged)
    Q_PROPERTY(Status  statusMode       READ statusMode       NOTIFY statusChanged)
    Q_PROPERTY(int    errorCount       READ errorCount       NOTIFY errorCountChanged)
    Q_PROPERTY(bool   hasActiveSensors READ hasActiveSensors NOTIFY activeSensorsChanged)
    Q_PROPERTY(QVariantList diLegend   READ diLegend         NOTIFY diLegendChanged)
    Q_PROPERTY(QVariantList analogSensors READ analogSensors NOTIFY analogSensorsListChanged)
    Q_PROPERTY(float  cpuTemp         READ cpuTemp          NOTIFY cpuTempChanged)
    Q_PROPERTY(QString watchdogStatus  READ watchdogStatus   NOTIFY watchdogChanged)
    // Trending axes — computed in C++ from the trend buffers so QML only
    // binds visuals (no min/max/margin math in QML).
    Q_PROPERTY(double trendXMin READ trendXMin NOTIFY trendAxesChanged)
    Q_PROPERTY(double trendXMax READ trendXMax NOTIFY trendAxesChanged)
    Q_PROPERTY(double trendYMin READ trendYMin NOTIFY trendAxesChanged)
    Q_PROPERTY(double trendYMax READ trendYMax NOTIFY trendAxesChanged)
    Q_PROPERTY(double trendWindowMs READ trendWindowMs CONSTANT)
    Q_PROPERTY(int trendTickCount READ trendTickCount CONSTANT)
    // Trending sensor filter (multi-select, rỗng = tất cả). QML (title bar)
    // ghi qua setTrendingSelectedIds; trục Y tự adapt theo tập đã chọn.
    Q_PROPERTY(QVariantList trendingSelectedIds READ trendingSelectedIds NOTIFY trendingFilterChanged)

public:
    // Single health encoding for C++ and QML (sidebar dots, taskbar).
    // Replaces magic ints and lastStatus string-matching in QML.
    enum Status { StatusIdle = 0, StatusOk = 1, StatusError = 2 };
    Q_ENUM(Status)

    // Ý định sau async stop: Nothing (Tester handoff), Restart
    // (refreshSensors: start lại sau stop), Retry (scheduleRetry: backoff).
    enum class AfterStop { Nothing, Restart, Retry };

    explicit MonitorController(MonitorModel *model,
                                ModbusTcpServerService *modbusTcp = nullptr,
                                QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(MonitorController)

    bool   isPolling()        const { return m_isPolling; }
    bool   isStopping()       const { return m_isStopping; }
    bool   isRetrying()       const { return m_retryTimer && m_retryTimer->isActive(); }
    bool   rtuConnected()     const { return m_rtuConnected.load(); }
    QString statusText()      const;
    Status statusMode()       const { return m_statusMode; }
    int    errorCount()       const { return m_errorCount; }
    bool   hasActiveSensors() const;
    QVariantList diLegend()   const { return m_diLegend; }
    QVariantList analogSensors() const { return m_analogSensors; }
    float  cpuTemp()          const { return m_cpuTemp; }
    QString watchdogStatus()  const { return m_watchdogStatus; }
    double trendXMin() const { return m_trendXMin; }
    double trendXMax() const { return m_trendXMax; }
    double trendYMin() const { return m_trendYMin; }
    double trendYMax() const { return m_trendYMax; }
    double trendWindowMs() const { return double(kTrendWindowMs); }
    int trendTickCount() const { return kTrendTickCount; }
    QVariantList trendingSelectedIds() const;

    // Axis window for the realtime chart (also the QML trim horizon).
    static constexpr qint64 kTrendWindowMs = 5 * 60 * 1000;
    // Major tick COUNT on the time axis (NOT milliseconds).
    static constexpr int kTrendTickCount = 6;

    // Pure axis math over explicit inputs (static so unit tests need no
    // controller instance, threads or DB). filterIds rỗng = tính trên mọi
    // buffer; non-empty = chỉ tính trên sensor được chọn (trục Y adapt).
    struct TrendAxes { double xMin = 0; double xMax = 0; double yMin = 0; double yMax = 1; };
    static TrendAxes computeTrendAxes(qint64 nowMs,
                                      const QHash<int, std::deque<std::pair<double,double>>> &buffers,
                                      const QHash<int, bool> &isDigital,
                                      const QSet<int> &filterIds = {});

    // Backoff delay calculation for retry
    static int computeRetryDelayMs(int retryCount);

    // REST snapshot (called from network thread)
    QVariantMap readingsSnapshot() const;

    Q_INVOKABLE QVariantList getTrendBuffer(int sensorId) const;

public slots:
    void startPolling();
    // Async: trả về ngay, hoàn tất trong finalizeStop() rồi thực hiện
    // after (Restart/Retry). stopPollingSync() chỉ dùng lúc app quit
    // (event loop sắp chết, không thể async).
    void stopPolling(AfterStop after = AfterStop::Nothing);
    void stopPollingSync();
    void refreshSensors();
    // Overload: accepts pre-built sensor maps from SensorListModel to skip
    // a redundant DB read (called from main.cpp after each model reset).
    void refreshSensorsFromList(const QList<QVariantMap> &maps);
    void registerHeartbeat(const QString &workerName);
    void writeDo(int sensorId, bool value);
    void setTrendingSelectedIds(const QVariantList &ids);

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
    void retryStateChanged();
    void messageSent(QString title, QString body);
    void recordsCommitted(int count);
    // Realtime trending signals
    void newDataPoint(int sensorId, double timestampMs, double value);
    void trendAxesChanged();
    void trendingFilterChanged();
    // Async stop hoàn tất: worker stop() đã chạy xong + thread đã chết +
    // cổng serial đã giải phóng. Tester chờ signal này mới được connect.
    void pollingFullyStopped();

private slots:
    void onDataReady(QVariantMap payload);
    void onModbusError(QString msg);
    void onConnectionChanged(bool connected);
    void onModbusStopped();
    void onWorkerAsyncStopped();
    void onDbError(QString msg);
    void onRecordsSaved(int count);
    void onAlarmChanged(QVariantMap info);
    void readCpuTemp();
    void checkWatchdog();

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
    void finishRetry();
    void applyStatus(const QString &tag, Status mode);
    void scheduleRetry(const QString &reason);
    void cancelRetry();
    void resetTrendBuffers(const QList<QVariantMap> &sensors);
    void pushTrendPoint(int sensorId, const QString &recordedAt, double value);
    void updateTrendAxes();
    void buildDiLegend(const QList<QVariantMap> &diSensors,
                       const QList<QVariantMap> &links);
    void syncLinkedDigitalCards(const QVariantMap &payload);
    void cacheReading(const QVariantMap &payload);
    void markReadingsCacheErr();
    void clearReadingsCache();

    MonitorModel            *m_model;
    ModbusTcpServerService  *m_mbtcp;

    // QPointer: thread tự deleteLater khi finished — QPointer tự null nên
    // không bao giờ gọi isRunning() trên object đã hủy
    // (SEGV Tester Connect, core 19:13 Pi .15).
    QPointer<QThread> m_modbusThread;
    QPointer<QThread> m_dbThread;
    // QPointer: worker tự deleteLater khi thread finished — mọi invokeMethod
    // check null trước khi post event sang thread đã chết.
    QPointer<QObject>        m_modbusWorker;
    QPointer<DatabaseWorker> m_dbWorker;

    std::atomic<bool> m_isPolling          {false};
    std::atomic<bool> m_rtuConnected       {false};
    bool              m_isStopping        = false;
    // Đếm workerStopped cho async stop (SingleShotConnection): đủ số lượng
    // worker còn sống lúc stopPolling → finalizeStop, không poll isRunning.
    int               m_pendingStops      = 0;
    // Ý định sau stopPolling async + lý do retry (finishRetry dùng).
    AfterStop         m_afterStop         = AfterStop::Nothing;
    QString           m_retryReason;
    Status    m_statusMode = StatusIdle;
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
    // sensor_id → true for DI/DO step series (drives the digital-only Y range)
    QHash<int, bool> m_trendIsDigital;
    // Multi-select filter cho trending (rỗng = tất cả sensor).
    QSet<int> m_trendingFilter;
    double m_trendXMin = 0;
    double m_trendXMax = 0;
    double m_trendYMin = 0;
    double m_trendYMax = 1;

    // REST readings cache
    mutable QMutex           m_readingsMutex;
    QHash<int, QVariantMap>  m_readingsCache;

    // Watchdog
    QTimer *m_watchdogTimer = nullptr;
    QTimer *m_cpuTimer      = nullptr;
    struct HeartbeatState { int misses = 0; double lastTime = 0; };
    QHash<QString, HeartbeatState> m_heartbeats;

    // Auto-retry after error (exponential backoff)
    QTimer *m_retryTimer = nullptr;
    int     m_retryCount = 0;
    static constexpr int kRetryBaseMs = 5000;   // 5s initial delay
    static constexpr int kRetryMaxMs  = 60000;  // cap 60s
};
