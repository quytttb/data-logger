#include "TesterWorker.h"
#include "utils/modbus/ModbusCodec.h"
#include "utils/modbus/ModbusPortGuard.h"
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
    abortAwait();
    if (m_client) {
        m_client->disconnectDevice();
        delete m_client;
        m_client = nullptr;
    }
}

void TesterWorker::doConnect(const QString &port, int baudrate,
                              int bytesize, const QString &parity, int stopbits) {
    if (port.trimmed().isEmpty()) {
        emit connectionResult(false, QStringLiteral("No serial port selected."));
        emit messageSent(QStringLiteral("Error"),
            QStringLiteral("No serial port selected."));
        return;
    }
    // Single-owner: monitor (hoặc tiến trình khác) đang giữ cổng thì báo
    // busy thay vì mở chồng client lên cùng port (SEGV core 19:13 Pi .15).
    if (!acquirePort(port)) {
        emit connectionResult(false,
            QStringLiteral("Serial port busy: %1").arg(port));
        emit messageSent(QStringLiteral("Error"),
            QStringLiteral("Serial port busy: %1. Stop monitoring or try again.").arg(port));
        return;
    }
    if (m_client) {
        // Reconnect khi idle: hủy scan/await cũ (bản block cũ để scan chạy
        // tiếp trên client mới — sai). Op mới không bị busy reject ở đây vì
        // doConnect là op quản lý kết nối, không phải op dữ liệu.
        abortAwait();
        finishScan();
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
        // Guard đã giữ (loại trừ double-open in-process) mà vẫn fail →
        // probe OS: EBUSY kernel (exclusive kẹt) thì heal ngay để user bấm
        // lại là được; lỗi khác chỉ báo, không restart vô ích.
        bool healed = false;
        {
            QSerialPort probe;
            probe.setPortName(port);
            if (!probe.open(QIODevice::ReadWrite)
                    && ModbusPortGuard::isStuckExclusiveError(probe.errorString())
                    && (!m_healCooldown.isValid() || m_healCooldown.hasExpired(kHealCooldownMs))) {
                m_healCooldown.restart();
                ModbusPortGuard::restartSimulatorForStuckPty();
                healed = true;
            }
        }
        releasePort();
        emit connectionResult(false,
            healed ? QStringLiteral("Serial port was busy — simulator restarting, try Connect again in a few seconds.")
                   : QStringLiteral("Failed to connect: %1").arg(port));
        if (!healed)
            emit messageSent(QStringLiteral("Error"),
                QStringLiteral("Failed to connect to %1").arg(port));
    }
}

bool TesterWorker::acquirePort(const QString &port) {
    if (m_portGuard.has_value()) return true;
    auto g = ModbusPortGuard::Guard::tryLock();
    if (!g) return false;
    // Probe: port bị tiến trình ngoài giữ (minicom...) thì cũng báo busy.
    // Mở + đóng ngay lập tức, vô hại với pty/tty thật.
    QSerialPort probe;
    probe.setPortName(port);
    if (!probe.open(QIODevice::ReadWrite))
        return false; // g hủy ở đây → unlock đúng 1 lần
    probe.close();
    m_portGuard = std::move(g);
    return true;
}

void TesterWorker::releasePort() {
    m_portGuard.reset(); // RAII unlock đúng 1 lần, kể cả gọi thừa
}

void TesterWorker::doDisconnect() {
    abortAwait();
    finishScan(); // chỉ emit scanFinished nếu scan đang chạy
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr;
        m_connected = false;
        emit connectionResult(false, QStringLiteral("Disconnected"));
    }
    releasePort();
}

// ── Async await core (1 in-flight tại 1 thời điểm, cùng thread) ──

bool TesterWorker::checkBusy(const char *op) {
    if (m_awaitReply || m_scanning) {
        emit messageSent(QStringLiteral("Busy"),
            QStringLiteral("%1 ignored: another operation is running.")
                .arg(QString::fromUtf8(op)));
        return true;
    }
    return false;
}

void TesterWorker::sendAndAwait(QModbusReply *reply, int timeoutMs, ReplyCont cont) {
    Q_ASSERT(!m_awaitReply);
    if (!m_replyTimer) {
        // Tạo lazy trên worker thread (mọi slot đều chạy ở đây).
        m_replyTimer = new QTimer(this);
        m_replyTimer->setSingleShot(true);
        connect(m_replyTimer, &QTimer::timeout, this, &TesterWorker::onAwaitTimeout);
    }
    if (!reply) {
        cont(nullptr, true);
        return;
    }
    connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
    m_awaitReply = reply;
    m_awaitCont = std::move(cont);
    connect(reply, &QModbusReply::finished, this, &TesterWorker::onAwaitFinished);
    m_replyTimer->start(timeoutMs);
}

void TesterWorker::onAwaitFinished() {
    auto *reply = qobject_cast<QModbusReply *>(sender());
    m_replyTimer->stop();
    auto cont = std::move(m_awaitCont);
    m_awaitReply = nullptr;
    m_awaitCont = {};
    cont(reply, false);
}

void TesterWorker::onAwaitTimeout() {
    auto *reply = m_awaitReply;
    auto cont = std::move(m_awaitCont);
    m_awaitReply = nullptr;
    m_awaitCont = {};
    cont(reply, true);
}

void TesterWorker::abortAwait() {
    if (m_replyTimer) m_replyTimer->stop();
    if (m_awaitReply) {
        disconnect(m_awaitReply, &QModbusReply::finished,
                   this, &TesterWorker::onAwaitFinished);
        m_awaitReply->deleteLater();
        m_awaitReply = nullptr;
    }
    m_awaitCont = {};
}

void TesterWorker::finishScan() {
    if (!m_scanning) return;
    m_scanning = false;
    emit scanFinished();
}

void TesterWorker::doReadRegister(int slaveId, int address,
                                   const QString &registerType,
                                   const QString &dataType,
                                   const QString &dataFormat) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (checkBusy("Read")) return;

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    QModbusDataUnit::RegisterType regEnum = ModbusCodec::toRegisterEnum(reg);

    const int count = ModbusCodec::registerCountForDataType(dataType);
    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply object."));
        return;
    }

    sendAndAwait(reply, kReplyWaitMs,
            [this, slaveId, address, reg, regEnum, dataType, dataFormat](
                    QModbusReply *reply, bool timedOut) {
        if (timedOut || !reply) {
            emit readCompleted({{QStringLiteral("ok"), false},
                                {QStringLiteral("error"), QStringLiteral("Response timeout")}});
            return;
        }
        if (reply->error() != QModbusDevice::NoError) {
            emit readCompleted({{QStringLiteral("ok"), false},
                                {QStringLiteral("error"), reply->errorString()}});
            return;
        }

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
        emit readCompleted({{QStringLiteral("ok"), true}, {QStringLiteral("raw"), raw},
                            {QStringLiteral("address"), address},
                            {QStringLiteral("slave_id"), slaveId},
                            {QStringLiteral("register_type"), reg}});
    });
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
    if (checkBusy("Write")) return;

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);
    if (reg == QStringLiteral("coil")) {
        writeCoilInternal(slaveId, address, value >= 0.5);
        return;
    }

    const QVector<quint16> regs = ModbusCodec::encodeRegisters(value, dataType, dataFormat);
    if (regs.isEmpty()) {
        emit writeCompleted({{QStringLiteral("ok"), false},
                             {QStringLiteral("error"), QStringLiteral("Value out of range or NaN/Inf for ") + dataType}});
        return;
    }

    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, address, regs.size());
    for (int i = 0; i < regs.size(); ++i) unit.setValue(i, regs[i]);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("No reply object."));
        return;
    }
    sendAndAwait(reply, kReplyWaitMs,
            [this](QModbusReply *reply, bool timedOut) {
        if (timedOut || !reply) {
            emit writeCompleted({{QStringLiteral("ok"), false},
                                 {QStringLiteral("error"), QStringLiteral("Response timeout")}});
            return;
        }
        emit writeCompleted({{QStringLiteral("ok"), reply->error() == QModbusDevice::NoError},
                             {QStringLiteral("error"), reply->errorString()}});
    });
}

void TesterWorker::doWriteSingle(const QString &registerType, int address,
                                  const QString &valueStr, int slaveId,
                                  const QString &dataType) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (checkBusy("Write")) return;

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
    if (checkBusy("Write")) return;
    writeCoilInternal(slaveId, address, value);
}

void TesterWorker::writeCoilInternal(int slaveId, int address, bool value) {
    if (!m_connected || !m_client) return;
    QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
    unit.setValue(0, value ? 1 : 0);
    auto *reply = m_client->sendWriteRequest(unit, slaveId);
    if (!reply) return;
    sendAndAwait(reply, kReplyWaitMs,
            [this](QModbusReply *reply, bool timedOut) {
        if (timedOut || !reply) {
            emit writeCompleted({{QStringLiteral("ok"), false},
                                 {QStringLiteral("error"), QStringLiteral("Response timeout")}});
            return;
        }
        emit writeCompleted({{QStringLiteral("ok"), reply->error() == QModbusDevice::NoError}});
    });
}

void TesterWorker::doScanSlavesById(int startId, int endId) {
    if (!m_connected || !m_client) {
        emit messageSent(QStringLiteral("Error"), QStringLiteral("Not connected."));
        return;
    }
    if (checkBusy("Scan")) { emit scanFinished(); return; }
    m_scanById = true;
    m_scanning = true;
    m_scanTotal = endId - startId + 1;
    m_scanCur = 0;
    m_scanIdCur = startId;
    m_scanIdEnd = endId;
    scanIdStep();
}

void TesterWorker::scanIdStep() {
    if (!m_scanning || !m_connected || !m_client) { finishScan(); return; }
    if (m_scanIdCur > m_scanIdEnd) { finishScan(); return; }
    const int id = m_scanIdCur++;
    emit scanProgressUpdated(++m_scanCur, m_scanTotal);
    QModbusDataUnit unit(QModbusDataUnit::HoldingRegisters, 0, 1);
    auto *reply = m_client->sendReadRequest(unit, id);
    if (!reply) { scanIdStep(); return; }
    sendAndAwait(reply, kReplyWaitMs, [this, id](QModbusReply *reply, bool timedOut) {
        if (timedOut || !reply) { scanIdStep(); return; } // slave vắng/bus treo — bỏ qua
        if (reply->error() == QModbusDevice::NoError)
            emit scanResultEmitted({{QStringLiteral("slave_id"), id},
                                    {QStringLiteral("found"), true}});
        scanIdStep();
    });
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
    if (checkBusy("Scan")) { emit scanFinished(); return; }

    const QString reg = ModbusCodec::normalizeRegisterType(registerType);

    m_scanById = false;
    m_scanning = true;
    m_scanStep  = qMax(1, registersPerRead);
    m_scanTotal = (endAddr - startAddr) / m_scanStep + 1;
    m_scanCur = 0;
    m_scanAddrCur = startAddr;
    m_scanAddrEnd = endAddr;
    m_scanSlave = slaveId;
    m_scanRegEnum = ModbusCodec::toRegisterEnum(reg);
    m_scanDataType = dataType;
    m_scanDataFormat = dataFormat;
    scanAddrStep();
}

void TesterWorker::scanAddrStep() {
    if (!m_scanning || !m_connected || !m_client) { finishScan(); return; }
    if (m_scanAddrCur > m_scanAddrEnd) { finishScan(); return; }
    const int addr = m_scanAddrCur;
    m_scanAddrCur += m_scanStep;
    emit scanProgressUpdated(++m_scanCur, m_scanTotal);

    const int count = (m_scanRegEnum == QModbusDataUnit::Coils
                    || m_scanRegEnum == QModbusDataUnit::DiscreteInputs)
        ? 1 : qMax(1, ModbusCodec::registerCountForDataType(m_scanDataType));

    QModbusDataUnit request(m_scanRegEnum, addr, count);
    auto *reply = m_client->sendReadRequest(request, m_scanSlave);
    if (!reply) { scanAddrStep(); return; }

    sendAndAwait(reply, kReplyWaitMs, [this, addr](QModbusReply *reply, bool timedOut) {
        if (timedOut || !reply) { scanAddrStep(); return; }
        if (reply->error() == QModbusDevice::NoError) {
            QModbusDataUnit unit = reply->result();
            double raw = 0;
            if (m_scanRegEnum == QModbusDataUnit::Coils || m_scanRegEnum == QModbusDataUnit::DiscreteInputs) {
                raw = unit.value(0) ? 1.0 : 0.0;
            } else {
                QVector<quint16> regs;
                for (uint i = 0; i < unit.valueCount(); ++i)
                    regs << unit.value(i);
                raw = ModbusCodec::decodeRegisters(regs, m_scanDataType, m_scanDataFormat);
            }
            const QString valStr = formatDecodedValue(raw, m_scanDataType);
            emit scanResultEmitted({{QStringLiteral("address"), addr},
                                    {QStringLiteral("value"), valStr}});
            emit scanResultByAddress(addr, valStr);
        }
        scanAddrStep();
    });
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
