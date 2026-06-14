#include "TesterController.h"
#include <QModbusDataUnit>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QEventLoop>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <cmath>
#include <cstring>

static TesterController *g_testerInstance = nullptr;

TesterController *TesterController::instance() { return g_testerInstance; }

void TesterController::setInstance(TesterController *controller)
{
    g_testerInstance = controller;
}

TesterController *TesterController::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(g_testerInstance);
    QQmlEngine::setObjectOwnership(g_testerInstance, QQmlEngine::CppOwnership);
    return g_testerInstance;
}

TesterController::TesterController(QObject *parent) : QObject(parent)
{
    refresh_ports();
}

TesterController::~TesterController() {
    disconnectSerial();
}

void TesterController::setStatus(const QString &s) {
    m_statusText = s;
    emit statusChanged();
}

void TesterController::setScanning(bool v)
{
    if (m_scanning == v) return;
    m_scanning = v;
    emit scanningChanged();
}

void TesterController::setConnecting(bool v)
{
    if (m_connecting == v) return;
    m_connecting = v;
    emit connectingChanged();
}

void TesterController::setStopping(bool v)
{
    if (m_stopping == v) return;
    m_stopping = v;
    emit stoppingChanged();
}

void TesterController::refresh_ports()
{
    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts())
        ports.append(info.portName());
    ports.sort();
    if (ports != m_availablePorts) {
        m_availablePorts = ports;
        emit availablePortsChanged();
    }
}

QString TesterController::normalizeRegisterType(const QString &uiLabel)
{
    const QString s = uiLabel.trimmed().toLower();
    if (s.contains(QStringLiteral("input register")))
        return QStringLiteral("input");
    if (s.contains(QStringLiteral("holding")))
        return QStringLiteral("holding");
    if (s.contains(QStringLiteral("coil")))
        return QStringLiteral("coil");
    if (s.contains(QStringLiteral("discrete")))
        return QStringLiteral("discrete_input");
    return s;
}

int TesterController::registerCountForDataType(const QString &dataType)
{
    if (dataType == QStringLiteral("float32")
        || dataType == QStringLiteral("int32")
        || dataType == QStringLiteral("uint32"))
        return 2;
    return 1;
}

double TesterController::decodeRegisters(const QVector<quint16> &regs,
                                         const QString &dataType,
                                         const QString &dataFormat) const
{
    if (regs.isEmpty()) return 0.0;
    if (regs.size() >= 2) {
        quint32 raw32 = (dataFormat == QStringLiteral("CDAB"))
            ? (quint32(regs[1]) << 16 | regs[0])
            : (quint32(regs[0]) << 16 | regs[1]);
        if (dataType == QStringLiteral("float32")) {
            float f = 0.f;
            memcpy(&f, &raw32, 4);
            return f;
        }
        if (dataType == QStringLiteral("int32"))  return qint32(raw32);
        if (dataType == QStringLiteral("uint32")) return raw32;
    }
    return dataType == QStringLiteral("int16") ? qint16(regs[0]) : regs[0];
}

QString TesterController::formatDecodedValue(double raw, const QString &dataType) const
{
    if (dataType == QStringLiteral("float32"))
        return QString::number(raw, 'f', 4);
    if (std::floor(raw) == raw)
        return QString::number(qint64(raw));
    return QString::number(raw, 'g', 6);
}

void TesterController::connectSerial(const QString &port, int baudrate,
                                      int bytesize, const QString &parity, int stopbits) {
    disconnectSerial();
    setConnecting(true);

    m_client = new QModbusRtuSerialClient(this);
    m_client->setConnectionParameter(QModbusDevice::SerialPortNameParameter, port);
    m_client->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, baudrate);
    m_client->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, bytesize);
    m_client->setConnectionParameter(QModbusDevice::SerialParityParameter,
        parity == "E" ? QSerialPort::EvenParity :
        parity == "O" ? QSerialPort::OddParity  : QSerialPort::NoParity);
    m_client->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, stopbits);
    m_client->setTimeout(1000);
    m_client->setNumberOfRetries(1);

    if (m_client->connectDevice()) {
        m_connected = true;
        setStatus(QStringLiteral("Connected: %1 @ %2 baud").arg(port).arg(baudrate));
        emit connectionChanged();
    } else {
        m_client->deleteLater();
        m_client = nullptr;
        setStatus(QStringLiteral("Failed to connect: %1").arg(port));
        emit messageSent(QStringLiteral("Error"), statusText());
    }
    setConnecting(false);
}

void TesterController::disconnectSerial() {
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr;
        m_connected = false;
        setStatus(QStringLiteral("Disconnected"));
        emit connectionChanged();
    }
}

void TesterController::readRegister(int slaveId, int address,
                                     const QString &registerType,
                                     const QString &dataType,
                                     const QString &dataFormat) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }

    const QString reg = normalizeRegisterType(registerType);
    QModbusDataUnit::RegisterType regEnum = QModbusDataUnit::HoldingRegisters;
    if (reg == QStringLiteral("input"))          regEnum = QModbusDataUnit::InputRegisters;
    else if (reg == QStringLiteral("coil"))      regEnum = QModbusDataUnit::Coils;
    else if (reg == QStringLiteral("discrete_input")) regEnum = QModbusDataUnit::DiscreteInputs;

    const int count = registerCountForDataType(dataType);
    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) { emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply.")); return; }

    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error() != QModbusDevice::NoError) {
        emit readResult({{QStringLiteral("ok"), false}, {QStringLiteral("error"), reply->errorString()}});
        reply->deleteLater();
        return;
    }

    QModbusDataUnit unit = reply->result();
    reply->deleteLater();

    double raw = 0;
    if (regEnum == QModbusDataUnit::Coils || regEnum == QModbusDataUnit::DiscreteInputs) {
        raw = unit.value(0) ? 1.0 : 0.0;
    } else {
        QVector<quint16> regs;
        for (uint i = 0; i < unit.valueCount(); ++i)
            regs << unit.value(i);
        raw = decodeRegisters(regs, dataType, dataFormat);
    }
    emit readResult({{QStringLiteral("ok"), true}, {QStringLiteral("raw"), raw},
                     {QStringLiteral("address"), address},
                     {QStringLiteral("slave_id"), slaveId},
                     {QStringLiteral("register_type"), reg}});
}

void TesterController::writeRegister(int slaveId, int address,
                                      const QString &registerType,
                                      const QString &dataType,
                                      const QString &dataFormat,
                                      double value) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    Q_UNUSED(dataFormat)

    const QString reg = normalizeRegisterType(registerType);
    if (reg == QStringLiteral("coil")) {
        writeCoil(slaveId, address, value >= 0.5);
        return;
    }

    QVector<quint16> regs;
    if (dataType == QStringLiteral("float32")) {
        float f = float(value); quint32 r; memcpy(&r, &f, 4);
        regs << quint16(r >> 16) << quint16(r & 0xFFFF);
    } else if (dataType == QStringLiteral("int32") || dataType == QStringLiteral("uint32")) {
        quint32 r = quint32(qint32(value));
        regs << quint16(r >> 16) << quint16(r & 0xFFFF);
    } else {
        regs << quint16(qint16(value));
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, regs.size());
    for (int i = 0; i < regs.size(); ++i) unit.setValue(i, regs[i]);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) { emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply.")); return; }
    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();
    const bool ok = (reply->error() == QModbusDevice::NoError);
    emit writeResult({{QStringLiteral("ok"), ok}, {QStringLiteral("error"), reply->errorString()}});
    reply->deleteLater();
}

QString TesterController::write_single(const QString &registerType, int address,
                                       const QString &valueStr, int slaveId,
                                       const QString &dataType)
{
    if (!m_connected || !m_client)
        return QStringLiteral("Not connected.");

    const QString reg = normalizeRegisterType(registerType);
    bool ok = false;
    QString err;

    if (reg == QStringLiteral("coil")) {
        const bool coilVal = valueStr.trimmed() == QStringLiteral("1")
                          || valueStr.trimmed().toLower() == QStringLiteral("true");
        QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
        unit.setValue(0, coilVal ? 1 : 0);
        auto *reply = m_client->sendWriteRequest(unit, slaveId);
        if (!reply) return QStringLiteral("No reply.");
        QEventLoop loop;
        connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
        loop.exec();
        ok = reply->error() == QModbusDevice::NoError;
        err = reply->errorString();
        reply->deleteLater();
    } else {
        bool convOk = false;
        const double val = valueStr.toDouble(&convOk);
        if (!convOk) return QStringLiteral("Invalid numeric value.");
        writeRegister(slaveId, address, reg, dataType, QStringLiteral("AB"), val);
        return QStringLiteral("SUCCESS");
    }

    return ok ? QStringLiteral("SUCCESS") : err;
}

void TesterController::writeCoil(int slaveId, int address, bool value) {
    if (!m_connected || !m_client) return;
    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    unit.setValue(0, value ? 1 : 0);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) return;
    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();
    emit writeResult({{QStringLiteral("ok"), reply->error() == QModbusDevice::NoError}});
    reply->deleteLater();
}

void TesterController::scanSlaves(int startId, int endId) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    setScanning(true);
    const int total = endId - startId + 1;
    int cur = 0;
    for (int id = startId; id <= endId && m_scanning; ++id) {
        ++cur;
        emit scanProgress(cur, total);
        QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, 0, 1);
        auto *reply = m_client->sendReadRequest(unit, id);
        if (!reply) continue;
        QEventLoop loop;
        connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
        loop.exec();
        if (reply->error() == QModbusDevice::NoError)
            emit scanResult({{QStringLiteral("slave_id"), id}, {QStringLiteral("found"), true}});
        reply->deleteLater();
    }
    setScanning(false);
}

void TesterController::scanSlaves(int startAddr, int endAddr, int registersPerRead,
                                  const QString &registerType, const QString &dataType,
                                  int slaveId, const QString &dataFormat)
{
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (startAddr > endAddr) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Start address must be ≤ end address."));
        return;
    }

    const QString reg = normalizeRegisterType(registerType);
    QModbusDataUnit::RegisterType regEnum = QModbusDataUnit::HoldingRegisters;
    if (reg == QStringLiteral("input"))          regEnum = QModbusDataUnit::InputRegisters;
    else if (reg == QStringLiteral("coil"))        regEnum = QModbusDataUnit::Coils;
    else if (reg == QStringLiteral("discrete_input")) regEnum = QModbusDataUnit::DiscreteInputs;

    const int step = qMax(1, registersPerRead);
    const int total = (endAddr - startAddr) / step + 1;
    setScanning(true);
    int cur = 0;

    for (int addr = startAddr; addr <= endAddr && m_scanning; addr += step) {
        ++cur;
        emit scanProgress(cur, total);

        const int count = (regEnum == QModbusDataUnit::Coils
                        || regEnum == QModbusDataUnit::DiscreteInputs)
            ? 1 : qMax(1, registerCountForDataType(dataType));

        QModbusDataUnit request(regEnum, addr, count);
        auto *reply = m_client->sendReadRequest(request, slaveId);
        if (!reply) continue;

        QEventLoop loop;
        connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
        loop.exec();

        if (reply->error() == QModbusDevice::NoError) {
            QModbusDataUnit unit = reply->result();
            double raw = 0;
            if (regEnum == QModbusDataUnit::Coils || regEnum == QModbusDataUnit::DiscreteInputs) {
                raw = unit.value(0) ? 1.0 : 0.0;
            } else {
                QVector<quint16> regs;
                for (uint i = 0; i < unit.valueCount(); ++i)
                    regs << unit.value(i);
                raw = decodeRegisters(regs, dataType, dataFormat);
            }
            const QString valStr = formatDecodedValue(raw, dataType);
            emit scanResult({{QStringLiteral("address"), addr}, {QStringLiteral("value"), valStr}});
            emit scanResultReceived(addr, valStr);
        }
        reply->deleteLater();
    }
    setScanning(false);
}

void TesterController::stopScan() {
    if (!m_scanning) return;
    setStopping(true);
    m_scanning = false;
    emit scanningChanged();
    setStopping(false);
}
