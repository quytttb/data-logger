#pragma once
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QModbusRtuSerialClient>

// Performs all blocking Modbus I/O on a dedicated worker thread so the GUI
// thread is never blocked by QEventLoop waits inside read/write/scan ops.
class TesterWorker : public QObject {
    Q_OBJECT
public:
    explicit TesterWorker(QObject *parent = nullptr);
    ~TesterWorker() override;

public slots:
    void doConnect(const QString &port, int baudrate,
                   int bytesize, const QString &parity, int stopbits);
    void doDisconnect();
    void doReadRegister(int slaveId, int address,
                        const QString &registerType,
                        const QString &dataType,
                        const QString &dataFormat);
    void doWriteRegister(int slaveId, int address,
                         const QString &registerType,
                         const QString &dataType,
                         const QString &dataFormat,
                         double value);
    void doWriteSingle(const QString &registerType, int address,
                       const QString &valueStr, int slaveId,
                       const QString &dataType);
    void doWriteCoil(int slaveId, int address, bool value);
    void doScanSlavesById(int startId, int endId);
    void doScanSlavesByAddr(int startAddr, int endAddr, int registersPerRead,
                            const QString &registerType, const QString &dataType,
                            int slaveId, const QString &dataFormat);
    void doStopScan();

signals:
    void connectionResult(bool connected, const QString &statusText);
    void readCompleted(const QVariantMap &result);
    void writeCompleted(const QVariantMap &result);
    void scanResultEmitted(const QVariantMap &result);
    void scanResultByAddress(int address, const QString &value);
    void scanProgressUpdated(int current, int total);
    void scanFinished();
    void messageSent(const QString &title, const QString &body);

private:
    QString formatDecodedValue(double raw, const QString &dataType) const;
    void writeCoilInternal(int slaveId, int address, bool value);

    QModbusRtuSerialClient *m_client  = nullptr;
    bool                    m_connected = false;
    bool                    m_scanning  = false;
};
