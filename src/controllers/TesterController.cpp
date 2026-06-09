#include "TesterController.h"
#include <QModbusDataUnit>
#include <QSerialPort>
#include <QEventLoop>
#include <QDebug>
#include <cstring>

TesterController::TesterController(QObject *parent) : QObject(parent) {}

TesterController::~TesterController() {
    disconnectSerial();
}

void TesterController::setStatus(const QString &s) {
    m_statusText = s;
    emit statusChanged();
}

void TesterController::connectSerial(const QString &port, int baudrate,
                                      int bytesize, const QString &parity, int stopbits) {
    disconnectSerial();

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
        emit messageSent("Error", statusText());
    }
}

void TesterController::disconnectSerial() {
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr;
        m_connected = false;
        setStatus("Disconnected");
        emit connectionChanged();
    }
}

void TesterController::readRegister(int slaveId, int address,
                                     const QString &registerType,
                                     const QString &dataType,
                                     const QString &dataFormat) {
    if (!m_connected || !m_client) {
        emit messageSent("Error", "Not connected."); return;
    }

    QModbusDataUnit::RegisterType regEnum = QModbusDataUnit::HoldingRegisters;
    if (registerType == "input")          regEnum = QModbusDataUnit::InputRegisters;
    else if (registerType == "coil")      regEnum = QModbusDataUnit::Coils;
    else if (registerType == "discrete_input") regEnum = QModbusDataUnit::DiscreteInputs;

    int count = (dataType == "float32" || dataType == "int32" || dataType == "uint32") ? 2 : 1;
    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) { emit messageSent("Error", "No reply."); return; }

    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error() != QModbusDevice::NoError) {
        emit readResult({{"ok", false}, {"error", reply->errorString()}});
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
        for (int i = 0; i < (int)unit.valueCount(); ++i) regs << unit.value(i);
        // Simple decode
        if (regs.size() >= 2) {
            quint32 raw32 = (dataFormat == "CDAB") ?
                (quint32(regs[1]) << 16 | regs[0]) :
                (quint32(regs[0]) << 16 | regs[1]);
            if (dataType == "float32") { float f; memcpy(&f, &raw32, 4); raw = f; }
            else if (dataType == "int32")  raw = (qint32)raw32;
            else if (dataType == "uint32") raw = raw32;
            else raw = regs[0];
        } else {
            raw = dataType == "int16" ? (qint16)regs[0] : regs[0];
        }
    }
    emit readResult({{"ok", true}, {"raw", raw}, {"address", address},
                     {"slave_id", slaveId}, {"register_type", registerType}});
}

void TesterController::writeRegister(int slaveId, int address,
                                      const QString &registerType,
                                      const QString &dataType,
                                      const QString &dataFormat,
                                      double value) {
    if (!m_connected || !m_client) { emit messageSent("Error", "Not connected."); return; }
    Q_UNUSED(dataFormat)

    if (registerType == "coil") {
        writeCoil(slaveId, address, value >= 0.5);
        return;
    }

    QVector<quint16> regs;
    if (dataType == "float32") {
        float f = float(value); quint32 r; memcpy(&r, &f, 4);
        regs << quint16(r >> 16) << quint16(r & 0xFFFF);
    } else if (dataType == "int32" || dataType == "uint32") {
        quint32 r = quint32(qint32(value));
        regs << quint16(r >> 16) << quint16(r & 0xFFFF);
    } else {
        regs << quint16(qint16(value));
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, regs.size());
    for (int i = 0; i < regs.size(); ++i) unit.setValue(i, regs[i]);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) { emit messageSent("Error", "No reply."); return; }
    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();
    bool ok = (reply->error() == QModbusDevice::NoError);
    emit writeResult({{"ok", ok}, {"error", reply->errorString()}});
    reply->deleteLater();
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
    emit writeResult({{"ok", reply->error() == QModbusDevice::NoError}});
    reply->deleteLater();
}

void TesterController::scanSlaves(int startId, int endId) {
    if (!m_connected || !m_client) { emit messageSent("Error", "Not connected."); return; }
    m_scanning = true;
    for (int id = startId; id <= endId && m_scanning; ++id) {
        QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, 0, 1);
        auto *reply = m_client->sendReadRequest(unit, id);
        if (!reply) continue;
        QEventLoop loop;
        connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
        loop.exec();
        if (reply->error() == QModbusDevice::NoError)
            emit scanResult({{"slave_id", id}, {"found", true}});
        reply->deleteLater();
    }
    m_scanning = false;
}

void TesterController::stopScan() { m_scanning = false; }
