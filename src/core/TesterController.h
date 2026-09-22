#pragma once
#include <QObject>
#include <QPointer>
#include <QThread>
#include <QTimer>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"

class TesterWorker;
class MonitorController;

// QML-facing singleton that forwards invokable calls to TesterWorker (which
// runs on a dedicated thread) and exposes state properties back to QML.
class TesterController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool   isConnected  READ isConnected  NOTIFY connectionChanged)
    Q_PROPERTY(bool   isConnecting READ isConnecting NOTIFY connectingChanged)
    Q_PROPERTY(bool   isScanning   READ isScanning   NOTIFY scanningChanged)
    Q_PROPERTY(bool   isStopping   READ isStopping   NOTIFY stoppingChanged)
    Q_PROPERTY(QString statusText  READ statusText   NOTIFY statusChanged)
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)

public:
    explicit TesterController(QObject *parent);

    DECLARE_QML_SINGLETON(TesterController)

    ~TesterController();

    bool    isConnected()  const { return m_connected; }
    bool    isConnecting() const { return m_connecting; }
    bool    isScanning()   const { return m_scanning; }
    bool    isStopping()   const { return m_stopping; }
    QString statusText()   const { return m_statusText; }
    QStringList availablePorts() const { return m_availablePorts; }

public slots:
    Q_INVOKABLE void connectSerial(const QString &port, int baudrate,
                                    int bytesize, const QString &parity, int stopbits);
    // Tester steals the RS-485 port: pause monitoring first (if running or
    // retrying) and connect once it is fully idle — no QML polling loop.
    Q_INVOKABLE void connectWithMonitorPause(MonitorController *monitor,
                                    const QString &port, int baudrate,
                                    int bytesize, const QString &parity, int stopbits);
    Q_INVOKABLE void disconnectSerial();
    Q_INVOKABLE void refresh_ports();

    Q_INVOKABLE void readRegister(int slaveId, int address,
                                   const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat);

    Q_INVOKABLE void writeRegister(int slaveId, int address,
                                    const QString &registerType,
                                    const QString &dataType,
                                    const QString &dataFormat,
                                    double value);

    Q_INVOKABLE void write_single(const QString &registerType, int address,
                                  const QString &valueStr, int slaveId,
                                  const QString &dataType);

    Q_INVOKABLE void writeCoil(int slaveId, int address, bool value);
    Q_INVOKABLE void scanSlaves(int startId, int endId);
    Q_INVOKABLE void scanSlaves(int startAddr, int endAddr, int registersPerRead,
                                const QString &registerType, const QString &dataType,
                                int slaveId, const QString &dataFormat);
    Q_INVOKABLE void stopScan();

signals:
    void connectionChanged();
    void connectingChanged();
    void scanningChanged();
    void stoppingChanged();
    void statusChanged();
    void availablePortsChanged();
    void messageSent(QString title, QString body);
    void readResult(QVariantMap result);
    void writeResult(QVariantMap result);
    void scanResult(QVariantMap result);
    void scanResultReceived(int address, const QString &value);
    void scanProgress(int current, int total);

private slots:
    void onConnectionResult(bool connected, const QString &statusText);    void onReadCompleted(const QVariantMap &result);
    void onWriteCompleted(const QVariantMap &result);
    void onScanResultEmitted(const QVariantMap &result);
    void onScanResultByAddress(int address, const QString &value);
    void onScanProgressUpdated(int current, int total);
    void onScanFinished();
    void tryPendingConnect();
    void resumeMonitorIfNeeded();
    void onConnectTimeout();

private:
    void setScanning(bool v);
    void setConnecting(bool v);
    void setStopping(bool v);
    void setStatus(const QString &s);

    // Worker + thread dùng QPointer: thread tự deleteLater khi finished.
    QPointer<TesterWorker> m_worker;
    QPointer<QThread>      m_workerThread;

    bool    m_connected   = false;
    bool    m_connecting  = false;
    bool    m_scanning    = false;
    bool    m_stopping    = false;
    QString m_statusText  = "Disconnected";
    QStringList m_availablePorts;

    // Connect-with-monitor-pause coordination (tester owns the serial port
    // while connected; monitoring resumes on disconnect/connection failure).
    QPointer<MonitorController> m_monitor;
    bool      m_monitorWasRunning = false;
    bool      m_waitingConnect    = false;
    // Timeout có context: pollingFullyStopped không tới thì báo Port busy
    // thay vì treo chờ vô hạn (Qt 6.11 singleShot có context tự cancel).
    QTimer   *m_connectTimeout = nullptr;
    QString   m_pendingPort;
    int       m_pendingBaudrate = 0;
    int       m_pendingBytesize = 0;
    QString   m_pendingParity;
    int       m_pendingStopbits = 0;
};
