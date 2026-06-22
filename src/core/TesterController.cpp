#include "TesterController.h"
#include "network/workers/TesterWorker.h"
#include "MonitorController.h"
#include <QSerialPortInfo>
#include <QFileInfo>
#include <QDebug>
#include <QDir>
#include <QQmlEngine>
#include <QJSEngine>
#include <algorithm>

IMPLEMENT_QML_SINGLETON(TesterController)

TesterController::TesterController(QObject *parent) : QObject(parent)
{
    m_worker       = new TesterWorker();
    m_workerThread = new QThread(this);

    m_worker->moveToThread(m_workerThread);
    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

    connect(m_worker, &TesterWorker::connectionResult,
            this,     &TesterController::onConnectionResult);
    connect(m_worker, &TesterWorker::readCompleted,
            this,     &TesterController::onReadCompleted);
    connect(m_worker, &TesterWorker::writeCompleted,
            this,     &TesterController::onWriteCompleted);
    connect(m_worker, &TesterWorker::scanResultEmitted,
            this,     &TesterController::onScanResultEmitted);
    connect(m_worker, &TesterWorker::scanResultByAddress,
            this,     &TesterController::onScanResultByAddress);
    connect(m_worker, &TesterWorker::scanProgressUpdated,
            this,     &TesterController::onScanProgressUpdated);
    connect(m_worker, &TesterWorker::scanFinished,
            this,     &TesterController::onScanFinished);
    connect(m_worker, &TesterWorker::messageSent,
            this,     &TesterController::messageSent);

    m_workerThread->start();
    refresh_ports();
}

TesterController::~TesterController() {
    QMetaObject::invokeMethod(m_worker, "doDisconnect", Qt::BlockingQueuedConnection);
    m_workerThread->quit();
    m_workerThread->wait(3000);
}

// ── Property setters ───────────────────────────────────────────────────────

void TesterController::setStatus(const QString &s) {
    m_statusText = s;
    emit statusChanged();
}

void TesterController::setScanning(bool v) {
    if (m_scanning == v) return;
    m_scanning = v;
    emit scanningChanged();
}

void TesterController::setConnecting(bool v) {
    if (m_connecting == v) return;
    m_connecting = v;
    emit connectingChanged();
}

void TesterController::setStopping(bool v) {
    if (m_stopping == v) return;
    m_stopping = v;
    emit stoppingChanged();
}

// ── QML invokables ─────────────────────────────────────────────────────────

void TesterController::refresh_ports()
{
    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts())
        ports.append(info.portName());
    ports.sort();

    QStringList virtualPorts;
    const QFileInfoList pts = QDir(QStringLiteral("/dev/pts"))
                                  .entryInfoList(QDir::System | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : pts) {
        if (fi.fileName() == QLatin1String("ptmx")) continue;
        virtualPorts.append(fi.absoluteFilePath());
    }
    const QFileInfoList ttyLinks = QDir(QStringLiteral("/tmp"))
                                       .entryInfoList({QStringLiteral("tty*")},
                                                      QDir::System | QDir::Files);
    for (const QFileInfo &fi : ttyLinks)
        virtualPorts.append(fi.absoluteFilePath());

    std::sort(virtualPorts.begin(), virtualPorts.end(),
              [](const QString &a, const QString &b) {
                  return a.compare(b, Qt::CaseInsensitive) < 0;
              });
    ports += virtualPorts;

    if (ports != m_availablePorts) {
        m_availablePorts = ports;
        emit availablePortsChanged();
    }
}

void TesterController::connectSerial(const QString &port, int baudrate,
                                      int bytesize, const QString &parity, int stopbits) {
    if (MonitorController::instance() && MonitorController::instance()->isPolling()) {
        setStatus(QStringLiteral("Cannot connect: Monitor is currently polling on the serial port."));
        emit messageSent(QStringLiteral("Port Conflict"),
                         QStringLiteral("Stop monitoring before using the Modbus Tester."));
        return;
    }
    setConnecting(true);
    QMetaObject::invokeMethod(m_worker, "doConnect", Qt::QueuedConnection,
                              Q_ARG(QString, port), Q_ARG(int, baudrate),
                              Q_ARG(int, bytesize), Q_ARG(QString, parity),
                              Q_ARG(int, stopbits));
}

void TesterController::disconnectSerial() {
    QMetaObject::invokeMethod(m_worker, "doDisconnect", Qt::QueuedConnection);
}

void TesterController::readRegister(int slaveId, int address,
                                     const QString &registerType,
                                     const QString &dataType,
                                     const QString &dataFormat) {
    QMetaObject::invokeMethod(m_worker, "doReadRegister", Qt::QueuedConnection,
                              Q_ARG(int, slaveId), Q_ARG(int, address),
                              Q_ARG(QString, registerType), Q_ARG(QString, dataType),
                              Q_ARG(QString, dataFormat));
}

void TesterController::writeRegister(int slaveId, int address,
                                      const QString &registerType,
                                      const QString &dataType,
                                      const QString &dataFormat,
                                      double value) {
    QMetaObject::invokeMethod(m_worker, "doWriteRegister", Qt::QueuedConnection,
                              Q_ARG(int, slaveId), Q_ARG(int, address),
                              Q_ARG(QString, registerType), Q_ARG(QString, dataType),
                              Q_ARG(QString, dataFormat), Q_ARG(double, value));
}

void TesterController::write_single(const QString &registerType, int address,
                                    const QString &valueStr, int slaveId,
                                    const QString &dataType) {
    QMetaObject::invokeMethod(m_worker, "doWriteSingle", Qt::QueuedConnection,
                              Q_ARG(QString, registerType), Q_ARG(int, address),
                              Q_ARG(QString, valueStr), Q_ARG(int, slaveId),
                              Q_ARG(QString, dataType));
}

void TesterController::writeCoil(int slaveId, int address, bool value) {
    QMetaObject::invokeMethod(m_worker, "doWriteCoil", Qt::QueuedConnection,
                              Q_ARG(int, slaveId), Q_ARG(int, address),
                              Q_ARG(bool, value));
}

void TesterController::scanSlaves(int startId, int endId) {
    if (!m_connected) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    setScanning(true);
    QMetaObject::invokeMethod(m_worker, "doScanSlavesById", Qt::QueuedConnection,
                              Q_ARG(int, startId), Q_ARG(int, endId));
}

void TesterController::scanSlaves(int startAddr, int endAddr, int registersPerRead,
                                   const QString &registerType, const QString &dataType,
                                   int slaveId, const QString &dataFormat) {
    if (!m_connected) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (startAddr > endAddr) {
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("Start address must be \u2264 end address."));
        return;
    }
    setScanning(true);
    QMetaObject::invokeMethod(m_worker, "doScanSlavesByAddr", Qt::QueuedConnection,
                              Q_ARG(int, startAddr), Q_ARG(int, endAddr),
                              Q_ARG(int, registersPerRead),
                              Q_ARG(QString, registerType), Q_ARG(QString, dataType),
                              Q_ARG(int, slaveId), Q_ARG(QString, dataFormat));
}

void TesterController::stopScan() {
    if (!m_scanning) return;
    setStopping(true);
    QMetaObject::invokeMethod(m_worker, "doStopScan", Qt::QueuedConnection);
}

// ── Worker result slots ────────────────────────────────────────────────────

void TesterController::onConnectionResult(bool connected, const QString &statusText) {
    m_connected = connected;
    setStatus(statusText);
    setConnecting(false);
    emit connectionChanged();
}

void TesterController::onReadCompleted(const QVariantMap &result) {
    emit readResult(result);
}

void TesterController::onWriteCompleted(const QVariantMap &result) {
    emit writeResult(result);
}

void TesterController::onScanResultEmitted(const QVariantMap &result) {
    emit scanResult(result);
}

void TesterController::onScanResultByAddress(int address, const QString &value) {
    emit scanResultReceived(address, value);
}

void TesterController::onScanProgressUpdated(int current, int total) {
    emit scanProgress(current, total);
}

void TesterController::onScanFinished() {
    setScanning(false);
    setStopping(false);
}
