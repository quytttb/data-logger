#pragma once
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QTimer>
#include <QModbusRtuSerialClient>
#include <QModbusReply>
#include <QModbusDataUnit>
#include <functional>
#include <optional>
#include "utils/modbus/ModbusPortGuard.h"

// Performs all Modbus I/O on a dedicated worker thread (Qt 6 async, không
// QEventLoop lồng): mỗi lúc 1 in-flight, finished/timeout chạy continuation.
// Op mới khi đang bận → báo Busy thay vì xếp chồng (tránh race reply).
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

private slots:
    void onAwaitFinished();
    void onAwaitTimeout();

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
    // Single-owner cổng RS-485 (ModbusPortGuard): giữ guard trong lúc
    // connected, tryLock fail hoặc probe mở port fail → báo busy.
    bool acquirePort(const QString &port);
    void releasePort();
    using ReplyCont = std::function<void(QModbusReply *, bool)>;
    bool checkBusy(const char *op);
    void sendAndAwait(QModbusReply *reply, int timeoutMs, ReplyCont cont);
    void abortAwait();
    void finishScan();
    void scanIdStep();
    void scanAddrStep();

    QModbusRtuSerialClient *m_client  = nullptr;
    bool                    m_connected = false;
    bool                    m_scanning  = false;
    // Giữ ModbusPortGuard trong lúc connected (RAII).
    std::optional<ModbusPortGuard::Guard> m_portGuard;
    // Async await state (1 in-flight tại 1 thời điểm, cùng thread).
    QTimer                  *m_replyTimer = nullptr;
    QModbusReply            *m_awaitReply = nullptr;
    std::function<void(QModbusReply *, bool)> m_awaitCont;
    // Scan chain state (1 scan tại 1 thời điểm).
    bool m_scanById = true;
    int  m_scanCur = 0, m_scanTotal = 0;
    int  m_scanIdCur = 0, m_scanIdEnd = 0;
    int  m_scanAddrCur = 0, m_scanAddrEnd = 0, m_scanStep = 1, m_scanSlave = 1;
    QModbusDataUnit::RegisterType m_scanRegEnum = QModbusDataUnit::HoldingRegisters;
    QString m_scanDataType, m_scanDataFormat;
};
