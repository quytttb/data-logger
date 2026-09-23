#include "ModbusWorker.h"
#include "utils/modbus/Formula.h"
#include "utils/modbus/ModbusCodec.h"
#include "utils/modbus/ModbusPortGuard.h"
#include <QModbusDataUnit>
#include <QModbusReply>
#include <QSerialPort>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QThread>
#include <QtDebug>
#include <QSet>
#include <QPair>
#include <cmath>
#include <utility>

namespace {
constexpr int kHeartbeatIntervalMs = 5000;  // liveness ping to MonitorController
}

ModbusWorker::ModbusWorker(QObject *parent) : QObject(parent) {}

ModbusWorker::~ModbusWorker() {
    // m_client cleanup is handled by stop() which runs on the correct thread.
    // By the time the destructor is called (via deleteLater after thread finished),
    // stop() has already run and disconnected/deleted the client.
}

void ModbusWorker::setAlarmBehavior(double hysteresis, bool doFailSafeOnReconnect) {
    m_alarmHysteresis = (hysteresis >= 0.0) ? hysteresis : 0.0;
    m_doFailSafeOnReconnect = doFailSafeOnReconnect;
}

bool ModbusWorker::evaluateAlarmWithHysteresis(double value,
                                               bool wasAlarm,
                                               const QString &prevAlarmType,
                                               bool hasMin, double minTh,
                                               bool hasMax, double maxTh,
                                               double hysteresis,
                                               QString &alarmTypeOut) {
    alarmTypeOut.clear();
    const double hyst = (hysteresis >= 0.0) ? hysteresis : 0.0;
    const bool prevHadMin = wasAlarm && prevAlarmType.contains("min");
    const bool prevHadMax = wasAlarm && prevAlarmType.contains("max");

    // Audit M5: when already in alarm for a given threshold, require the value
    // to move back PAST the safe side of the band (hysteresis) before
    // releasing, so relays don't chatter around the threshold.
    bool minActive = hasMin && (prevHadMin ? value <= minTh + hyst
                                           : value <= minTh);
    bool maxActive = hasMax && (prevHadMax ? value >= maxTh - hyst
                                           : value >= maxTh);

    if (minActive) alarmTypeOut = "min";
    if (maxActive) alarmTypeOut = alarmTypeOut.isEmpty() ? "max" : "min+max";

    return minActive || maxActive;
}

void ModbusWorker::configure(const QString &port, int baudrate, int bytesize,
                              const QString &parity, int stopbits, int timeout,
                              int defaultPollInterval) {
    m_port = port;
    m_baudrate = baudrate;
    m_bytesize = bytesize;
    m_parity = parity;
    m_stopbits = stopbits;
    m_timeout = timeout * 1000;           // convert s → ms
    m_defaultPollInterval = defaultPollInterval * 1000; // s → ms
}

void ModbusWorker::setSensors(const QList<QVariantMap> &sensors) {
    m_sensors = sensors;
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (const auto &s : sensors)
        m_nextPollMs[s["id"].toInt()] = now;
}

void ModbusWorker::setDigitalIos(const QHash<int, QList<QVariantMap>> &ioMap) {
    m_digitalIos = ioMap;
}

void ModbusWorker::start() {
    m_running = true;

    m_client = new QModbusRtuSerialClient(this);

    // Timer cho reply timeout của async pump (sống trên worker thread).
    if (!m_replyTimer) {
        m_replyTimer = new QTimer(this);
        m_replyTimer->setSingleShot(true);
        connect(m_replyTimer, &QTimer::timeout, this, &ModbusWorker::onAwaitTimeout);
    }

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(kHeartbeatIntervalMs);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &ModbusWorker::onHeartbeatTimer);
    m_heartbeatTimer->start();

    if (!connectToPort()) {
        // Start retry timer
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
        return;
    }
    // connectToPort đã ensure poll timer + kick round poll đầu.
}

void ModbusWorker::stop() {
    m_running = false;
    // Hủy await đang treo + xóa queue: mọi continuation kiểm tra m_running
    // nên không chạy tiếp; cùng thread nên tuyệt đối an toàn.
    abortAwait();
    m_opQueue.clear();
    m_pumpActive = false;
    if (m_pollTimer)      m_pollTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();
    if (m_client)         m_client->disconnectDevice();
    releasePort();
    emit workerStopped();
}

void ModbusWorker::ensurePollTimer() {
    if (!m_pollTimer) {
        m_pollTimer = new QTimer(this);
        m_pollTimer->setInterval(m_defaultPollInterval);
        connect(m_pollTimer, &QTimer::timeout, this, &ModbusWorker::onPollTimer);
    }
    if (!m_pollTimer->isActive())
        m_pollTimer->start();
}

// ── Async serial pump ────────────────────────────────────────────────
// Mọi request Modbus đi qua FIFO, mỗi lúc 1 in-flight. Mỗi step gửi request
// rồi trả về event loop; finished/timeout chạy continuation. Không
// QEventLoop lồng, không block — stop() chỉ cần hủy await + xóa queue.

void ModbusWorker::enqueueOp(std::function<void()> op) {
    m_opQueue.append(std::move(op));
    if (!m_pumpActive)
        pumpNextOp();
}

void ModbusWorker::pumpNextOp() {
    if (!m_running) {
        m_opQueue.clear();
        m_pumpActive = false;
        return;
    }
    if (m_opQueue.isEmpty()) {
        m_pumpActive = false;
        return;
    }
    m_pumpActive = true;
    auto op = std::move(m_opQueue.first());
    m_opQueue.pop_front();
    op(); // async: kết thúc bằng opDone()
}

void ModbusWorker::opDone() {
    if (!m_running) {
        m_opQueue.clear();
        m_pumpActive = false;
        return;
    }
    pumpNextOp();
}

void ModbusWorker::sendAndAwait(QModbusReply *reply, int timeoutMs, ReplyCont cont) {
    Q_ASSERT(!m_awaitReply);
    if (!reply) {
        cont(nullptr, true);
        return;
    }
    // Reply tự deleteLater khi finished — handler chỉ đọc result trong slot.
    connect(reply, &QModbusReply::finished, reply, &QObject::deleteLater);
    m_awaitReply = reply;
    m_awaitCont = std::move(cont);
    connect(reply, &QModbusReply::finished, this, &ModbusWorker::onAwaitFinished);
    m_replyTimer->start(timeoutMs);
}

void ModbusWorker::onAwaitFinished() {
    auto *reply = qobject_cast<QModbusReply *>(sender());
    m_replyTimer->stop();
    auto cont = std::move(m_awaitCont);
    m_awaitReply = nullptr;
    m_awaitCont = {};
    if (!m_running) return; // stop() giữa chừng — drop, pump đã reset
    cont(reply, false);
}

void ModbusWorker::onAwaitTimeout() {
    auto *reply = m_awaitReply;
    auto cont = std::move(m_awaitCont);
    m_awaitReply = nullptr;
    m_awaitCont = {};
    // Reply có thể finished sau — deleteLater đã gắn lúc gửi nên tự dọn.
    if (!m_running) return;
    cont(reply, true);
}

void ModbusWorker::abortAwait() {
    if (m_replyTimer) m_replyTimer->stop();
    if (m_awaitReply) {
        disconnect(m_awaitReply, &QModbusReply::finished,
                   this, &ModbusWorker::onAwaitFinished);
        m_awaitReply->deleteLater();
        m_awaitReply = nullptr;
    }
    m_awaitCont = {};
}

bool ModbusWorker::acquirePort() {
    if (m_portGuard.has_value()) return true;
    m_portGuard = ModbusPortGuard::Guard::tryLock();
    return m_portGuard.has_value();
}

void ModbusWorker::releasePort() {
    m_portGuard.reset(); // RAII unlock đúng 1 lần, kể cả gọi thừa
}

bool ModbusWorker::connectToPort() {
    if (!m_client)
        m_client = new QModbusRtuSerialClient(this); // recreate after timeout reset

    // Single-owner: Tester đang giữ cổng thì báo busy, thử lại sau (backoff).
    if (!acquirePort()) {
        m_connected = false;
        emit modbusError(QStringLiteral("Serial port busy, retrying %1").arg(m_port));
        return false;
    }

    m_client->setConnectionParameter(QModbusDevice::SerialPortNameParameter, m_port);
    m_client->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, m_baudrate);
    m_client->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, m_bytesize);
    m_client->setConnectionParameter(QModbusDevice::SerialParityParameter,
        m_parity == "E" ? QSerialPort::EvenParity :
        m_parity == "O" ? QSerialPort::OddParity  : QSerialPort::NoParity);
    m_client->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, m_stopbits);
    m_client->setTimeout(m_timeout);
    m_client->setNumberOfRetries(1);

    if (m_client->connectDevice()) {
        m_connected = true;
        m_backoffMs = 1000;
        m_consecutiveBusy = 0; // heal xong / hết kẹt — reset ngưỡng
        emit connectionChanged(true);
        qInfo() << "ModbusWorker: connected to" << m_port;
        // Audit M5: fail-safe policy is configurable. Default (true) forces a
        // known-OFF coil state on (re)connect so a stale latched relay can
        // never disagree with the app's reported state. Reset coil là op đầu
        // trong pump nên xong mới tới round poll (giữ đúng thứ tự bản block).
        // Khi fail-safe tắt: quên cache để poll sau tự converge (không ghi
        // coil ngay) — giữ nguyên M5.
        if (m_doFailSafeOnReconnect) {
            enqueueOp([this]() {
                resetDoCoilsAsync([this]() { opDone(); });
            });
        } else {
            // Forget cached alarm/coil state so the next poll re-establishes
            // the desired coil values, but do NOT write the coils now.
            m_alarmStates.clear();
            m_alarmTypes.clear();
            m_doStates.clear(); // unknown physical state → updateDoCoils rewrites
        }
        ensurePollTimer();
        onPollTimer(); // enqueue round poll (chạy sau reset op trong pump)
        return true;
    }

    m_connected = false;
    emit connectionChanged(false);
    // Phân biệt EBUSY kernel (exclusive kẹt — heal được bằng restart
    // simulator) với lỗi khác (cáp rút, baud sai, mất device — chỉ retry).
    // QModbusDevice chỉ báo ConnectionError chung chung nên probe trực tiếp
    // bằng QSerialPort để lấy lỗi OS chính xác (mở fail là vô hại).
    if (probePortBusy()) {
        ++m_consecutiveBusy;
        emit modbusError(QStringLiteral("Serial port busy (PTY exclusive stuck): %1").arg(m_port));
        if (m_consecutiveBusy >= kBusyHealThreshold
                && (!m_healCooldown.isValid() || m_healCooldown.hasExpired(kHealCooldownMs))) {
            m_healCooldown.restart();
            m_consecutiveBusy = 0;
            ModbusPortGuard::restartSimulatorForStuckPty();
        }
    } else {
        m_consecutiveBusy = 0;
        emit modbusError(QStringLiteral("Cannot connect to %1").arg(m_port));
    }
    return false;
}

bool ModbusWorker::probePortBusy() const {
    QSerialPort probe;
    probe.setPortName(m_port);
    if (probe.open(QIODevice::ReadWrite))
        return false; // mở được → không kẹt exclusive
    return ModbusPortGuard::isStuckExclusiveError(probe.errorString());
}

void ModbusWorker::tryReconnect() {
    if (!m_running) return;
    // Thành công: reset coil + kick poll đã làm trong connectToPort.
    // Thất bại: backoff rồi thử lại.
    if (!connectToPort()) {
        m_backoffMs = qMin(m_backoffMs * 2, kBackoffMax);
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
    }
}

void ModbusWorker::onPollTimer() {
    if (!m_running) return;
    if (!m_connected || !m_client || m_client->state() != QModbusDevice::ConnectedState) {
        if (m_pollTimer) m_pollTimer->stop();
        m_connected = false;
        emit connectionChanged(false);
        emit modbusError(QStringLiteral("Connection lost on %1").arg(m_port));
        m_backoffMs = 1000;
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
        return;
    }
    // Round trước chưa xong (timeout chồng chất) — bỏ qua tick này để pump
    // không bao giờ có 2 in-flight (bản block cũ serialize bằng block).
    if (m_pumpActive || !m_opQueue.isEmpty()) return;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QList<QVariantMap> due;
    for (const auto &cfg : std::as_const(m_sensors)) {
        const int sid = cfg["id"].toInt();
        if (now >= m_nextPollMs.value(sid, 0)) {
            due.append(cfg);
            const int interval = cfg.value("poll_interval", 3).toInt() * 1000;
            m_nextPollMs[sid] = now + interval;
        }
    }
    if (due.isEmpty()) return;
    enqueueOp([this, due]() { pollSensorAt(0, due); });
}

void ModbusWorker::pollSensorAt(int idx, const QList<QVariantMap> &due) {
    if (!m_running || idx >= due.size()) { opDone(); return; }
    pollSensorAsync(due[idx], [this, idx, due]() { pollSensorAt(idx + 1, due); });
}

void ModbusWorker::onHeartbeatTimer() {
    if (m_running)
        emit heartbeat("ModbusWorker");
}

void ModbusWorker::pollSensorAsync(const QVariantMap &cfg, OpDone done) {
    const QString stype = cfg.value("sensor_type", "ANALOG").toString();
    if (stype == "DI")           pollStandaloneDiAsync(cfg, done);
    else if (stype == "DO")      pollStandaloneDoAsync(cfg, done);
    else                         pollAnalogAsync(cfg, done);
}

void ModbusWorker::pollAnalogAsync(const QVariantMap &cfg, OpDone done) {
    const int sensorId    = cfg["id"].toInt();
    const int slaveId     = cfg["slave_id"].toInt();
    const int address     = cfg["register_address"].toInt();
    const QString regType = ModbusCodec::normalizeRegisterType(
        cfg.value("register_type", "holding").toString());
    const QString dataType = cfg.value("data_type", "int16").toString();
    const QString dataFormat = cfg.value("data_format", "AB").toString();
    const QString coeff   = cfg.value("coefficient", "{}").toString();

    // Determine QModbusDataUnit::RegisterType
    const QModbusDataUnit::RegisterType regEnum = ModbusCodec::toRegisterEnum(regType);
    const int count = ModbusCodec::registerCountForDataType(dataType);

    if (!m_running || !m_client) { done(); return; }
    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit modbusError(QStringLiteral("sensor %1: no reply").arg(sensorId));
        done();
        return;
    }
    sendAndAwait(reply, replyWaitMs(),
            [this, cfg, sensorId, regEnum, dataType, dataFormat, coeff, done](
                    QModbusReply *reply, bool timedOut) {
        if (!m_running) return; // stop() giữa chừng — drop, pump đã reset
        if (timedOut || !reply) {
            emit modbusError(QStringLiteral("sensor %1: reply timeout").arg(sensorId));
            resetConnectionAfterHang();
            done();
            return;
        }
        if (reply->error() != QModbusDevice::NoError) {
            emit modbusError(QStringLiteral("sensor %1: %2")
                             .arg(sensorId).arg(reply->errorString()));
            done();
            return;
        }

        const QModbusDataUnit unit = reply->result();
        double rawValue = 0.0;
        if (regEnum == QModbusDataUnit::Coils || regEnum == QModbusDataUnit::DiscreteInputs) {
            rawValue = unit.value(0) ? 1.0 : 0.0;
        } else {
            // Decode 16/32-bit register values
            QVector<quint16> regs;
            for (int i = 0; i < unit.valueCount(); ++i)
                regs.append(unit.value(i));
            rawValue = ModbusCodec::decodeRegisters(regs, dataType, dataFormat);
        }

        double value = Formula::applyFormula(rawValue, coeff);
        if (!std::isfinite(value))
            value = 0.0;
        if (!std::isfinite(rawValue))
            rawValue = 0.0;

        auto minTh = cfg.value("min_threshold");
        auto maxTh = cfg.value("max_threshold");
        const bool hasMin = !minTh.isNull();
        const bool hasMax = !maxTh.isNull();
        QString alarmType;
        // Audit M5: hysteresis prevents relay chatter (giữ nguyên logic).
        const bool prevAlarm  = m_alarmStates.value(sensorId, false);
        const QString prevTyp = m_alarmTypes.value(sensorId);
        const bool isAlarm = evaluateAlarmWithHysteresis(
            value, prevAlarm, prevTyp,
            hasMin, minTh.isValid() ? minTh.toDouble() : 0.0,
            hasMax, maxTh.isValid() ? maxTh.toDouble() : 0.0,
            m_alarmHysteresis, alarmType);

        m_alarmStates[sensorId] = isAlarm;
        m_alarmTypes[sensorId]  = alarmType;
        if (isAlarm != prevAlarm)
            emit alarmChanged({{"sensor_id", sensorId}, {"is_alarm", isAlarm}, {"alarm_type", alarmType}});

        // Converge DO coils (idempotent, chỉ ghi khi khác) rồi đọc DI —
        // giữ đúng thứ tự bản block (updateDoCoils trước readDiStates).
        writeDoChain(buildDoWrites(), 0,
                [this, cfg, sensorId, value, rawValue, isAlarm, alarmType, done]() {
            if (!m_running) return;
            const QList<QVariantMap> channels = m_digitalIos.value(sensorId);
            readDiChain(sensorId, channels, 0, {},
                    [this, cfg, sensorId, value, rawValue, isAlarm, alarmType, done](
                            QList<QVariantMap> diStates) {
                if (!m_running) return;
                QVariantList doStatesList;
                for (const auto &ch : m_digitalIos.value(sensorId)) {
                    if (ch.value("io_type") == "DO" && ch.value("active", true).toBool())
                        doStatesList.append(QVariantMap{{"id", ch["id"]},
                            {"state", m_doStates.value(ch["id"].toInt(), false)}});
                }

                QString status = "00";
                for (const auto &di : diStates) {
                    if (di.value("state").toBool()) {
                        QString dt = di.value("di_type").toString();
                        if (dt == "02") { status = "02"; break; }
                        else if (dt == "03" && status != "02") status = "03";
                        else if (dt == "01" && status != "02" && status != "03") status = "01";
                        else if (status == "00") status = dt;
                    }
                }

                QVariantList diStatesList;
                for (const auto &di : diStates)
                    diStatesList.append(QVariant(di));

                emit dataReady({
                    {"sensor_id",   sensorId},
                    {"raw_value",   rawValue},
                    {"value",       std::round(value * 10000.0) / 10000.0},
                    {"status",      status},
                    {"recorded_at", QDateTime::currentDateTime().toString(Qt::ISODate)},
                    {"is_alarm",    isAlarm},
                    {"alarm_type",  alarmType.isEmpty() ? QStringLiteral("") : alarmType},
                    {"di_states",   diStatesList},
                    {"do_states",   doStatesList},
                });
                done();
            });
        });
    });
}

// Pure aggregation tách từ updateDoCoils cũ: gom desired ON + địa chỉ coil
// cho mọi DO (idempotent: chỉ ghi khi khác state đã biết).
QList<ModbusWorker::DoWrite> ModbusWorker::buildDoWrites() const {
    QHash<int, bool> desired;                 // doSensorId -> desired ON
    QHash<int, QPair<int, int>> coilAddr;     // doSensorId -> (slaveId, address)
    for (auto it = m_digitalIos.constBegin(); it != m_digitalIos.constEnd(); ++it) {
        const int analogId       = it.key();
        const bool analogAlarm   = m_alarmStates.value(analogId, false);
        const QString analogType = m_alarmTypes.value(analogId);
        for (const auto &ch : it.value()) {
            if (ch.value("io_type") != "DO" || !ch.value("active", true).toBool())
                continue;
            const int doId    = ch.value("id").toInt();
            const int addr    = ch.value("address", ch.value("register_address", 0)).toInt();
            const int slaveId = ch.value("slave_id").toInt();
            coilAddr[doId] = qMakePair(slaveId, addr);
            bool on = false;
            if (analogAlarm) {
                if (ch.value("trigger_on_max", true).toBool() && analogType.contains("max")) on = true;
                if (ch.value("trigger_on_min", true).toBool() && analogType.contains("min")) on = true;
            }
            desired[doId] = desired.value(doId, false) || on;
        }
    }
    QList<DoWrite> out;
    for (auto it = desired.constBegin(); it != desired.constEnd(); ++it) {
        const int doId  = it.key();
        const bool want = it.value();
        // Skip only when we are certain the coil already holds the desired value.
        if (m_doStates.contains(doId) && m_doStates.value(doId) == want)
            continue;
        const QPair<int, int> sa = coilAddr.value(doId);
        out.append({doId, sa.first, sa.second, want});
    }
    return out;
}

void ModbusWorker::writeDoChain(const QList<DoWrite> &writes, int idx, OpDone done) {
    if (!m_running || !m_client || idx >= writes.size()) { done(); return; }
    const DoWrite w = writes[idx];
    QModbusDataUnit unit(QModbusDataUnit::Coils, w.address, 1);
    unit.setValue(0, w.want ? 1 : 0);
    auto *reply = m_client->sendWriteRequest(unit, w.slaveId);
    if (!reply) { writeDoChain(writes, idx + 1, done); return; } // cũ: continue
    sendAndAwait(reply, replyWaitMs(),
            [this, writes, idx, done](QModbusReply *reply, bool timedOut) {
        if (!m_running) return;
        if (timedOut || !reply) {
            // Cũ: break (bỏ các write còn lại) nhưng vẫn tiếp tục sensor flow
            // (DI read fail-fast trên client null) — ở đây done() để chain
            // trên (pollAnalog) đi tiếp, giữ đúng semantics.
            emit modbusError(QStringLiteral("DO coil %1 write timeout").arg(writes[idx].doId));
            resetConnectionAfterHang();
            done();
            return;
        }
        if (reply->error() == QModbusDevice::NoError)
            m_doStates[writes[idx].doId] = writes[idx].want;  // only trust on confirmed write
        writeDoChain(writes, idx + 1, done);
    });
}

void ModbusWorker::readDiChain(int sensorId, const QList<QVariantMap> &channels, int idx,
                               QList<QVariantMap> results,
                               std::function<void(QList<QVariantMap>)> done) {
    Q_UNUSED(sensorId)
    if (!m_running) return;
    // Bỏ qua kênh không phải DI/inactive (giữ đúng filter bản block).
    while (idx < channels.size()) {
        const auto &ch = channels[idx];
        if (ch.value("io_type") == "DI" && ch.value("active", true).toBool())
            break;
        ++idx;
    }
    if (!m_client || m_client->state() != QModbusDevice::ConnectedState || idx >= channels.size()) {
        done(results);
        return;
    }
    const auto ch = channels[idx];
    const int addr    = ch.value("address", ch.value("register_address", 0)).toInt();
    const int slaveId = ch["slave_id"].toInt();

    QModbusDataUnit req(QModbusDataUnit::DiscreteInputs, addr, 1);
    auto *reply = m_client->sendReadRequest(req, slaveId);
    if (!reply) {
        results.append({{"id", ch["id"]}, {"label", ch["label"]},
                        {"di_type", ch["di_type"]}, {"state", QVariant()}});
        readDiChain(sensorId, channels, idx + 1, results, done);
        return;
    }
    sendAndAwait(reply, replyWaitMs(),
            [this, sensorId, channels, idx, ch, results, done](QModbusReply *reply, bool timedOut) mutable {
        if (!m_running) return;
        if (timedOut || !reply) {
            // Cũ: break — abort các DI còn lại, trả kết quả đã có.
            emit modbusError(QStringLiteral("DI channel %1 timeout").arg(ch["id"].toInt()));
            resetConnectionAfterHang();
            done(results);
            return;
        }
        bool state = false;
        if (reply->error() == QModbusDevice::NoError) state = reply->result().value(0);
        results.append({{"id", ch["id"]}, {"label", ch.value("label")},
                        {"di_type", ch.value("di_type")}, {"state", state}});
        readDiChain(sensorId, channels, idx + 1, results, done);
    });
}

void ModbusWorker::resetConnectionAfterHang() {
    if (m_pollTimer)      m_pollTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();
    m_connected = false;
    if (m_client) {
        m_client->disconnectDevice();
        m_client->deleteLater();
        m_client = nullptr; // connectToPort() recreates it via backoff
    }
    releasePort(); // cổng thực sự rảnh — Tester có thể lấy trong lúc backoff
    emit connectionChanged(false);
    m_backoffMs = 1000;
    if (m_running)
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
}


void ModbusWorker::pollStandaloneDiAsync(const QVariantMap &cfg, OpDone done) {
    const int sensorId = cfg["id"].toInt();
    const int slaveId  = cfg["slave_id"].toInt();
    const int address  = cfg["register_address"].toInt();

    if (!m_running || !m_client) { done(); return; }
    QModbusDataUnit request(QModbusDataUnit::DiscreteInputs, address, 1);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit modbusError(QStringLiteral("DI no reply sensor %1").arg(sensorId));
        done();
        return;
    }
    sendAndAwait(reply, replyWaitMs(),
            [this, sensorId, done](QModbusReply *reply, bool timedOut) {
        if (!m_running) return;
        if (timedOut || !reply) {
            emit modbusError(QStringLiteral("DI reply timeout sensor %1").arg(sensorId));
            resetConnectionAfterHang();
            done();
            return;
        }
        bool state = false;
        if (reply->error() == QModbusDevice::NoError)
            state = reply->result().value(0);

        emit dataReady({
            {"sensor_id",   sensorId},
            {"raw_value",   state ? 1 : 0},
            {"value",       state ? 1 : 0},
            {"status",      QString("00")},
            {"recorded_at", QDateTime::currentDateTime().toString(Qt::ISODate)},
            {"is_alarm",    false},
            {"alarm_type",  QStringLiteral("")},
            {"di_states",   QVariantList{}},
        });
        done();
    });
}

void ModbusWorker::pollStandaloneDoAsync(const QVariantMap &cfg, OpDone done) {
    const int sensorId = cfg["id"].toInt();
    const int slaveId  = cfg["slave_id"].toInt();
    const int address  = cfg["register_address"].toInt();

    if (!m_running || !m_client) { done(); return; }
    QModbusDataUnit request(QModbusDataUnit::Coils, address, 1);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit modbusError(QStringLiteral("DO no reply sensor %1").arg(sensorId));
        done();
        return;
    }
    sendAndAwait(reply, replyWaitMs(),
            [this, sensorId, done](QModbusReply *reply, bool timedOut) {
        if (!m_running) return;
        if (timedOut || !reply) {
            emit modbusError(QStringLiteral("DO reply timeout sensor %1").arg(sensorId));
            resetConnectionAfterHang();
            done();
            return;
        }
        bool state = false;
        if (reply->error() != QModbusDevice::NoError) {
            emit modbusError(QStringLiteral("DO sensor %1: %2").arg(sensorId).arg(reply->errorString()));
            done();
            return; // Không phát OFF giả — giữ trạng thái cũ, tránh ghi DB sai
        }
        state = reply->result().value(0);
        m_doStates[sensorId] = state;

        emit dataReady({
            {"sensor_id",   sensorId},
            {"raw_value",   state ? 1 : 0},
            {"value",       state ? 1 : 0},
            {"status",      state ? QString("ON") : QString("OFF")},
            {"recorded_at", QDateTime::currentDateTime().toString(Qt::ISODate)},
            {"is_alarm",    false},
            {"alarm_type",  QStringLiteral("")},
            {"di_states",   QVariantList{}},
        });
        done();
    });
}

void ModbusWorker::writeSingleCoil(int sensorId, bool value) {
    // Q_INVOKABLE từ UI: đưa vào pump FIFO để serialize với poll round
    // (bản block cũ serialize bằng queued slot tuần tự).
    enqueueOp([this, sensorId, value]() {
        if (!m_running) return;
        if (!m_client || m_client->state() != QModbusDevice::ConnectedState) {
            qWarning() << "writeSingleCoil: not connected";
            opDone();
            return;
        }
        for (const auto &cfg : std::as_const(m_sensors)) {
            if (cfg["id"].toInt() != sensorId)
                continue;
            const int slaveId = cfg["slave_id"].toInt();
            const int address = cfg["register_address"].toInt();
            QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
            unit.setValue(0, value ? 1 : 0);
            auto *reply = m_client->sendWriteRequest(unit, slaveId);
            if (!reply) { opDone(); return; }
            sendAndAwait(reply, replyWaitMs(),
                    [this, sensorId, value](QModbusReply *reply, bool timedOut) {
                if (!m_running) return;
                if (!timedOut && reply && reply->error() == QModbusDevice::NoError)
                    m_doStates[sensorId] = value;
                else if (timedOut || !reply) {
                    emit modbusError(QStringLiteral("write coil %1 timeout").arg(sensorId));
                    resetConnectionAfterHang();
                }
                opDone();
            });
            return;
        }
        opDone(); // không tìm thấy sensor
    });
}


void ModbusWorker::resetDoCoilsAsync(OpDone done) {
    // Forget cached alarm/coil state so the next poll re-establishes everything.
    m_alarmStates.clear();
    m_alarmTypes.clear();
    if (!m_running || !m_client || m_client->state() != QModbusDevice::ConnectedState) {
        m_doStates.clear();  // unknown physical state; force a rewrite on first poll
        done();
        return;
    }

    QList<DoWrite> writes;
    QSet<int> doneIds;
    for (auto it = m_digitalIos.constBegin(); it != m_digitalIos.constEnd(); ++it) {
        for (const auto &ch : it.value()) {
            if (ch.value("io_type") != "DO") continue;
            const int doId = ch.value("id").toInt();
            if (doneIds.contains(doId)) continue;
            doneIds.insert(doId);
            const int addr    = ch.value("address", ch.value("register_address", 0)).toInt();
            const int slaveId = ch.value("slave_id").toInt();
            writes.append({doId, slaveId, addr, false});
        }
    }
    resetWriteAt(writes, 0, done);
}

void ModbusWorker::resetWriteAt(const QList<DoWrite> &writes, int idx, OpDone done) {
    if (!m_running || !m_client || idx >= writes.size()) { done(); return; }
    const DoWrite w = writes[idx];
    QModbusDataUnit unit(QModbusDataUnit::Coils, w.address, 1);
    unit.setValue(0, 0);
    auto *reply = m_client->sendWriteRequest(unit, w.slaveId);
    if (!reply) {
        m_doStates.remove(w.doId);
        resetWriteAt(writes, idx + 1, done);
        return;
    }
    sendAndAwait(reply, replyWaitMs(),
            [this, writes, idx, done](QModbusReply *reply, bool timedOut) {
        if (!m_running) return;
        const int doId = writes[idx].doId;
        if (timedOut || !reply) {
            emit modbusError(QStringLiteral("DO coil %1 reset timeout").arg(doId));
            resetConnectionAfterHang();
            done(); // connection was reset — abort remaining resets
            return;
        }
        if (reply->error() == QModbusDevice::NoError)
            m_doStates[doId] = false;
        else
            m_doStates.remove(doId);  // leave unknown so updateDoCoils retries
        resetWriteAt(writes, idx + 1, done);
    });
}
