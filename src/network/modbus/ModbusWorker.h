#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QVariantMap>
#include <QList>
#include <QHash>
#include <QModbusRtuSerialClient>
#include "utils/system/AppDefaults.h"

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

private:
    bool connectToPort();
    // Chờ reply với timeout; khi timeout báo lỗi, lên lịch hủy reply an toàn
    // (chỉ delete khi finished thực sự fire) và reset cổng serial bị kẹt.
    bool waitReply(QModbusReply *reply, const QString &timeoutMsg);
    void resetConnectionAfterHang();
    void pollSingle(const QVariantMap &sensorCfg);
    void pollAnalog(const QVariantMap &cfg);
    void pollStandaloneDi(const QVariantMap &cfg);
    void pollStandaloneDo(const QVariantMap &cfg);

    QList<QVariantMap>       readDiStates(int sensorId);
    // Converge physical DO coils to the desired state aggregated across every
    // analog they are attached to (idempotent: only writes when state differs).
    void                     updateDoCoils();
    // Force all DO coils OFF on (re)connect so a stale latched relay can never
    // disagree with the app's reported state.
    void                     resetDoCoils();

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
