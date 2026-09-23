#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QVariantMap>
#include <QList>
#include <QHash>
#include <QModbusRtuSerialClient>
#include <QModbusReply>
#include <QModbusDevice>
#include <QElapsedTimer>
#include <functional>
#include <optional>
#include "utils/system/AppDefaults.h"
#include "utils/modbus/ModbusPortGuard.h"

// Wraps a QModbusRtuSerialClient and polls configured sensors on a worker thread.
class ModbusWorker : public QObject {
    Q_OBJECT

public:
    explicit ModbusWorker(QObject *parent = nullptr);
    ~ModbusWorker();

    void configure(const QString &port, int baudrate, int bytesize,
                   const QString &parity, int stopbits, int timeout,
                   int defaultPollInterval);

    // Audit M5: alarm hysteresis (absolute; 0 = off) to stop relay chatter
    // around thresholds, and the DO fail-safe policy on (re)connect.
    void setAlarmBehavior(double hysteresis, bool doFailSafeOnReconnect);

    // Called before start(); list of sensor dicts with all required keys.
    void setSensors(const QList<QVariantMap> &sensors);
    void setDigitalIos(const QHash<int, QList<QVariantMap>> &ioMap);

    // Manual DO write (called from main thread, executes on worker thread).
    Q_INVOKABLE void writeSingleCoil(int sensorId, bool value);

    // Audit M5: hàm thuần xác định trạng thái alarm theo ngưỡng min/max, có
    // hysteresis khi THOÁT alarm (khi đã trong alarm thì phải vượt ngưỡng về
    // phía an toàn thêm một đoạn hysteresis mới được giải phóng). Public +
    // static để unit test trực tiếp không cần phần cứng Modbus.
    static bool evaluateAlarmWithHysteresis(double value,
                                            bool wasAlarm,
                                            const QString &prevAlarmType,
                                            bool hasMin, double minTh,
                                            bool hasMax, double maxTh,
                                            double hysteresis,
                                            QString &alarmTypeOut);

public slots:
    void start();
    void stop();

signals:
    void dataReady(QVariantMap payload);
    void modbusError(QString message);
    void connectionChanged(bool connected);
    void alarmChanged(QVariantMap info);
    void workerStopped();
    void heartbeat(QString workerName);

private slots:
    void onPollTimer();
    void onHeartbeatTimer();
    void tryReconnect();
    void onAwaitFinished();
    void onAwaitTimeout();

private:
    bool connectToPort();
    // Serial op pump (Qt 6 async, không QEventLoop lồng): mọi request Modbus
    // đi qua hàng đợi FIFO, mỗi lúc 1 in-flight. Mỗi step gửi request rồi
    // trả về event loop; finished/timeout chạy continuation. Cùng thread nên
    // không cần lock; stop() hủy await + xóa queue là an toàn tuyệt đối.
    struct DoWrite { int doId = 0; int slaveId = 0; int address = 0; bool want = false; };
    using OpDone = std::function<void()>;
    using ReplyCont = std::function<void(QModbusReply *reply, bool timedOut)>;
    void enqueueOp(std::function<void()> op);
    void pumpNextOp();
    void opDone();
    void pollSensorAt(int idx, const QList<QVariantMap> &due);
    void sendAndAwait(QModbusReply *reply, int timeoutMs, ReplyCont cont);
    void abortAwait();
    // Một sensor poll hoàn chỉnh (analog/DI/DO) rồi gọi done().
    void pollSensorAsync(const QVariantMap &cfg, OpDone done);
    void pollAnalogAsync(const QVariantMap &cfg, OpDone done);
    void pollStandaloneDiAsync(const QVariantMap &cfg, OpDone done);
    void pollStandaloneDoAsync(const QVariantMap &cfg, OpDone done);
    void readDiChain(int sensorId, const QList<QVariantMap> &channels, int idx,
                     QList<QVariantMap> results,
                     std::function<void(QList<QVariantMap>)> done);
    void writeDoChain(const QList<DoWrite> &writes, int idx, OpDone done);
    QList<DoWrite> buildDoWrites() const;
    void resetDoCoilsAsync(OpDone done);
    void resetWriteAt(const QList<DoWrite> &writes, int idx, OpDone done);
    void ensurePollTimer();
    void resetConnectionAfterHang();
    // Single-owner cổng RS-485 (ModbusPortGuard): giữ guard trong suốt thời
    // gian connected, thả khi stop()/reset. tryLock fail → báo busy.
    bool acquirePort();
    void releasePort();
    // Probe OS-level: mở thử bằng QSerialPort để phân biệt EBUSY kernel
    // (exclusive kẹt) với lỗi khác. Mở fail là vô hại, không giữ fd.
    bool probePortBusy() const;

    QModbusRtuSerialClient  *m_client = nullptr;
    QTimer                  *m_pollTimer = nullptr;
    QTimer                  *m_heartbeatTimer = nullptr;

    static constexpr int kDefaultBaudrate       = AppDefaults::serialBaudrate;
    static constexpr int kDefaultBytesize       = AppDefaults::serialBytesize;
    static constexpr int kDefaultStopbits       = AppDefaults::serialStopbits;
    static constexpr int kDefaultTimeoutMs      = 1000;
    static constexpr int kDefaultPollIntervalMs = 3000;
    static constexpr int kInitialBackoffMs      = 1000;
    static constexpr int kBackoffMax            = 30000;

    QString  m_port;
    int      m_baudrate = kDefaultBaudrate;
    int      m_bytesize = kDefaultBytesize;
    QString  m_parity   = AppDefaults::serialParity;
    int      m_stopbits = kDefaultStopbits;
    int      m_timeout  = kDefaultTimeoutMs;            // ms
    int      m_defaultPollInterval = kDefaultPollIntervalMs; // ms

    // H-4 fix: mọi chờ reply Modbus phải có timeout (cáp có thể rút giữa request).
    int replyWaitMs() const { return m_timeout * 2 + 500; }

    bool     m_running = false;
    bool     m_connected = false;
    int      m_backoffMs = kInitialBackoffMs;
    // Async pump state (chỉ chạm trên worker thread — không cần lock).
    QTimer                  *m_replyTimer = nullptr;
    QModbusReply            *m_awaitReply = nullptr;
    ReplyCont                m_awaitCont;
    QList<std::function<void()>> m_opQueue;
    bool                     m_pumpActive = false;
    // Transient: danh sách radical DO writes đang chain (tham số explicit
    // qua các chain step, không dùng member để tránh state treo).
    // Giữ ModbusPortGuard trong lúc connected (RAII: reset() là unlock).
    std::optional<ModbusPortGuard::Guard> m_portGuard;
    // Auto-heal exclusive kẹt: EBUSY liên tiếp đủ ngưỡng + hết cooldown thì
    // restart simulator (tạo lại cặp pty). Không phải mọi "Cannot connect".
    int          m_consecutiveBusy = 0;
    QElapsedTimer m_healCooldown;
    static constexpr int kBusyHealThreshold = 3;
    static constexpr qint64 kHealCooldownMs = 60000;

    // Audit M5
    double   m_alarmHysteresis = 0.0;
    bool     m_doFailSafeOnReconnect = true;

    QList<QVariantMap>           m_sensors;
    QHash<int, QList<QVariantMap>> m_digitalIos;
    QHash<int, bool>             m_alarmStates;
    QHash<int, QString>          m_alarmTypes;  // sensor_id -> current alarm type ("min"/"max"/...)
    QHash<int, bool>             m_doStates;
    QHash<int, qint64>           m_nextPollMs; // sensor_id -> epoch ms of next poll
};
