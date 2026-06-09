#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QVariantMap>
#include <QList>
#include <QHash>
#include <QModbusRtuSerialClient>

// Wraps a QModbusRtuSerialClient and polls the configured sensors on a worker
// thread. Mirrors Python workers/modbus_worker.py.
class ModbusWorker : public QObject {
    Q_OBJECT

public:
    explicit ModbusWorker(QObject *parent = nullptr);
    ~ModbusWorker();

    void configure(const QString &port, int baudrate, int bytesize,
                   const QString &parity, int stopbits, int timeout,
                   int defaultPollInterval);

    // Called before start(); list of sensor dicts with all required keys.
    void setSensors(const QList<QVariantMap> &sensors);
    void setDigitalIos(const QHash<int, QList<QVariantMap>> &ioMap);

    // Manual DO write (called from main thread, executes on worker thread).
    Q_INVOKABLE void writeSingleCoil(int sensorId, bool value);

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
    void pollSingle(const QVariantMap &sensorCfg);
    void pollAnalog(const QVariantMap &cfg);
    void pollStandaloneDi(const QVariantMap &cfg);
    void pollStandaloneDo(const QVariantMap &cfg);

    QList<QVariantMap>       readDiStates(int sensorId);
    void                     driveDoRelays(int sensorId, bool isAlarm, const QString &alarmType);
    static double applyFormula(double raw, const QString &coeffJson);

    QModbusRtuSerialClient  *m_client = nullptr;
    QTimer                  *m_pollTimer = nullptr;
    QTimer                  *m_heartbeatTimer = nullptr;

    QString  m_port;
    int      m_baudrate = 9600;
    int      m_bytesize = 8;
    QString  m_parity   = "N";
    int      m_stopbits = 1;
    int      m_timeout  = 1000;      // ms
    int      m_defaultPollInterval = 3000; // ms

    bool     m_running = false;
    bool     m_connected = false;
    int      m_backoffMs = 1000;
    static constexpr int kBackoffMax = 30000;

    QList<QVariantMap>           m_sensors;
    QHash<int, QList<QVariantMap>> m_digitalIos;
    QHash<int, bool>             m_alarmStates;
    QHash<int, bool>             m_doStates;
    QHash<int, qint64>           m_nextPollMs; // sensor_id -> epoch ms of next poll
};
