#pragma once
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QModbusRtuSerialClient>

// Interactive Modbus tester — read/write individual registers.
// Mirrors Python ui/controllers/tester_controller.py.
class TesterController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool   isConnected  READ isConnected  NOTIFY connectionChanged)
    Q_PROPERTY(QString statusText  READ statusText   NOTIFY statusChanged)

public:
    explicit TesterController(QObject *parent = nullptr);
    ~TesterController();

    bool    isConnected() const { return m_connected; }
    QString statusText()  const { return m_statusText; }

public slots:
    Q_INVOKABLE void connectSerial(const QString &port, int baudrate,
                                    int bytesize, const QString &parity, int stopbits);
    Q_INVOKABLE void disconnectSerial();

    Q_INVOKABLE void readRegister(int slaveId, int address,
                                   const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat);

    Q_INVOKABLE void writeRegister(int slaveId, int address,
                                    const QString &registerType,
                                    const QString &dataType,
                                    const QString &dataFormat,
                                    double value);

    Q_INVOKABLE void writeCoil(int slaveId, int address, bool value);
    Q_INVOKABLE void scanSlaves(int startId, int endId);
    Q_INVOKABLE void stopScan();

signals:
    void connectionChanged();
    void statusChanged();
    void messageSent(QString title, QString body);
    void readResult(QVariantMap result);
    void writeResult(QVariantMap result);
    void scanResult(QVariantMap result);

private:
    QModbusRtuSerialClient *m_client = nullptr;
    bool    m_connected  = false;
    bool    m_scanning   = false;
    QString m_statusText = "Disconnected";

    void setStatus(const QString &s);
};
