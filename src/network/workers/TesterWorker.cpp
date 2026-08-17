#include "TesterWorker.h"
#include "utils/modbus/ModbusCodec.h"
#include "utils/modbus/ModbusWait.h"
#include <QModbusDataUnit>
#include <QModbusReply>
#include <QSerialPort>
#include <QDebug>
#include <cmath>
#include <cstring>

namespace {
constexpr int kClientTimeoutMs = 1000;  // Modbus client response timeout
// Chờ reply luôn có timeout (AGENTS rule): 2× client timeout + margin.
constexpr int kReplyWaitMs = kClientTimeoutMs * 2 + 500;
}

TesterWorker::TesterWorker(QObject *parent) : QObject(parent) {}

TesterWorker::~TesterWorker() {
    if (m_client) {
        m_client->disconnectDevice();
        delete m_client;
        m_client = nullptr;
    }
}

void TesterWorker::doConnect(const QString &port, int baudrate,
                              int bytesize, const QString &parity, int stopbits) {
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr;
        m_connected = false;
    }

    m_client = new QModbusRtuSerialClient(this);
    m_client->setConnectionParameter(QModbusDevice::SerialPortNameParameter, port);
    m_client->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, baudrate);
    m_client->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, bytesize);
    m_client->setConnectionParameter(QModbusDevice::SerialParityParameter,
        parity == "E" ? QSerialPort::EvenParity :
        parity == "O" ? QSerialPort::OddParity  : QSerialPort::NoParity);
    m_client->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, stopbits);
    m_client->setTimeout(kClientTimeoutMs);
    m_client->setNumberOfRetries(1);

    if (m_client->connectDevice()) {
        m_connected = true;
        emit connectionResult(true,
            QStringLiteral("Connected: %1 @ %2 baud").arg(port).arg(baudrate));
    } else {
        m_client->deleteLater();
        m_client = nullptr;
        emit connectionResult(false,
            QStringLiteral("Failed to connect: %1").arg(port));
        emit messageSent(QStringLiteral("Error"),
            QStringLiteral("Failed to connect to %1").arg(port));
    }
}

void TesterWorker::doDisconnect() {
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr;
        m_connected = false;
        emit connectionResult(false, QStringLiteral("Disconnected"));
    }
}

void TesterWorker::doReadRegister(int slaveId, int address,
                                   const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    QModbusDataUnit::RegisterType regEnum = ModbusCodec::toRegisterEnum(reg);

    const int count = ModbusCodec::registerCountForDataType(dataType);
    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply object."));
        return;
    }

    if (!ModbusWait::waitForReply(reply, kReplyWaitMs)) {
        // Timeout: trả lỗi, chỉ hủy reply khi nó thực sự kết thúc.
        connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
        emit readCompleted({{QStringLiteral("ok"), false},
                            {QStringLiteral("error"), QStringLiteral("Response timeout")}});
        return;
    }

    if (reply->error() != QModbusDevice::NoError) {
        emit readCompleted({{QStringLiteral("ok"), false},
                            {QStringLiteral("error"), reply->errorString()}});
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
        raw = ModbusCodec::decodeRegisters(regs, dataType, dataFormat);
    }
    emit readCompleted({{QStringLiteral("ok"), true}, {QStringLiteral("raw"), raw},
                        {QStringLiteral("address"), address},
                        {QStringLiteral("slave_id"), slaveId},
                        {QStringLiteral("register_type"), reg}});
}

void TesterWorker::doWriteRegister(int slaveId, int address,
                                    const QString &registerType,
                                    const QString &dataType,
                                    const QString &dataFormat,
                                    double value) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    Q_UNUSED(dataFormat)

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    if (reg == QStringLiteral("coil")) {
        writeCoilInternal(slaveId, address, value >= 0.5);
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
    if (!reply) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply object."));
        return;
    }
    bool ok;
    QString errorText;
    if (!ModbusWait::waitForReply(reply, kReplyWaitMs)) {
        connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
        ok = false;
        errorText = QStringLiteral("Response timeout");
    } else {
        ok = (reply->error() == QModbusDevice::NoError);
        errorText = reply->errorString();
        reply->deleteLater();
    }
    emit writeCompleted({{QStringLiteral("ok"), ok},
                         {QStringLiteral("error"), errorText}});
}

void TesterWorker::doWriteSingle(const QString &registerType, int address,
                                  const QString &valueStr, int slaveId,
                                  const QString &dataType) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    if (reg == QStringLiteral("coil")) {
        const bool coilVal = valueStr.trimmed() == QStringLiteral("1")
                          || valueStr.trimmed().toLower() == QStringLiteral("true");
        writeCoilInternal(slaveId, address, coilVal);
    } else {
        bool convOk = false;
        const double val = valueStr.toDouble(&convOk);
        if (!convOk) {
            emit messageSent(QStringLiteral("Error"), QStringLiteral("Invalid numeric value."));
            return;
        }
        doWriteRegister(slaveId, address, reg, dataType, QStringLiteral("AB"), val);
    }
}

void TesterWorker::doWriteCoil(int slaveId, int address, bool value) {
    writeCoilInternal(slaveId, address, value);
}

void TesterWorker::writeCoilInternal(int slaveId, int address, bool value) {
    if (!m_connected || !m_client) return;
    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    unit.setValue(0, value ? 1 : 0);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) return;
    if (!ModbusWait::waitForReply(reply, kReplyWaitMs)) {
        connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
        emit writeCompleted({{QStringLiteral("ok"), false},
                             {QStringLiteral("error"), QStringLiteral("Response timeout")}});
        return;
    }
    emit writeCompleted({{QStringLiteral("ok"), reply->error() == QModbusDevice::NoError}});
    reply->deleteLater();
}

void TesterWorker::doScanSlavesById(int startId, int endId) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    m_scanning = true;
    const int total = endId - startId + 1;
    int cur = 0;
    for (int id = startId; id <= endId && m_scanning; ++id) {
        ++cur;
        emit scanProgressUpdated(cur, total);
        QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, 0, 1);
        auto *reply = m_client->sendReadRequest(unit, id);
        if (!reply) continue;
        if (!ModbusWait::waitForReply(reply, kReplyWaitMs)) {
            // Không có slave tại id này (hoặc bus treo) — bỏ qua và dọn reply an toàn.
            connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
            continue;
        }
        if (reply->error() == QModbusDevice::NoError)
            emit scanResultEmitted({{QStringLiteral("slave_id"), id},
                                    {QStringLiteral("found"), true}});
        reply->deleteLater();
    }
    m_scanning = false;
    emit scanFinished();
}

void TesterWorker::doScanSlavesByAddr(int startAddr, int endAddr, int registersPerRead,
                                       const QString &registerType, const QString &dataType,
                                       int slaveId, const QString &dataFormat) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (startAddr > endAddr) {
        emit messageSent(QStringLiteral("Error"),
                         QStringLiteral("Start address must be \u2264 end address."));
        return;
    }

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    QModbusDataUnit::RegisterType regEnum = ModbusCodec::toRegisterEnum(reg);

    const int step  = qMax(1, registersPerRead);
    const int total = (endAddr - startAddr) / step + 1;
    m_scanning = true;
    int cur = 0;

    for (int addr = startAddr; addr <= endAddr && m_scanning; addr += step) {
        ++cur;
        emit scanProgressUpdated(cur, total);

        const int count = (regEnum == QModbusDataUnit::Coils
                        || regEnum == QModbusDataUnit::DiscreteInputs)
            ? 1 : qMax(1, ModbusCodec::registerCountForDataType(dataType));

        QModbusDataUnit request(regEnum, addr, count);
        auto *reply = m_client->sendReadRequest(request, slaveId);
        if (!reply) continue;

        if (!ModbusWait::waitForReply(reply, kReplyWaitMs)) {
            connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
            continue;
        }

        if (reply->error() == QModbusDevice::NoError) {
            QModbusDataUnit unit = reply->result();
            double raw = 0;
            if (regEnum == QModbusDataUnit::Coils || regEnum == QModbusDataUnit::DiscreteInputs) {
                raw = unit.value(0) ? 1.0 : 0.0;
            } else {
                QVector<quint16> regs;
                for (uint i = 0; i < unit.valueCount(); ++i)
                    regs << unit.value(i);
                raw = ModbusCodec::decodeRegisters(regs, dataType, dataFormat);
            }
            const QString valStr = formatDecodedValue(raw, dataType);
            emit scanResultEmitted({{QStringLiteral("address"), addr},
                                    {QStringLiteral("value"), valStr}});
            emit scanResultByAddress(addr, valStr);
        }
        reply->deleteLater();
    }
    m_scanning = false;
    emit scanFinished();
}

void TesterWorker::doStopScan() {
    m_scanning = false;
}

// ── Helpers ────────────────────────────────────────────────────────────────

QString TesterWorker::formatDecodedValue(double raw, const QString &dataType) const {
    if (dataType == QStringLiteral("float32"))
        return QString::number(raw, 'f', 4);
    if (std::floor(raw) == raw)
        return QString::number(qint64(raw));
    return QString::number(raw, 'g', 6);
}
