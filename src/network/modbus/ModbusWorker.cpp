#include "ModbusWorker.h"
#include "utils/Formula.h"
#include <QModbusDataUnit>
#include <QSerialPort>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QThread>
#include <QtDebug>
#include <cmath>
#include <utility>

// Forward declaration — defined at end of file
static double decodeRegisters(const QVector<quint16> &regs, const QString &dataType, const QString &fmt);

ModbusWorker::ModbusWorker(QObject *parent) : QObject(parent) {}

ModbusWorker::~ModbusWorker() {
    if (m_client) {
        m_client->disconnectDevice();
        delete m_client;
    }
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

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(5000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &ModbusWorker::onHeartbeatTimer);
    m_heartbeatTimer->start();

    if (!connectToPort()) {
        // Start retry timer
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
        return;
    }

    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(m_defaultPollInterval);
    connect(m_pollTimer, &QTimer::timeout, this, &ModbusWorker::onPollTimer);
    m_pollTimer->start();
    onPollTimer(); // immediate first poll
}

void ModbusWorker::stop() {
    m_running = false;
    if (m_pollTimer)      m_pollTimer->stop();
    if (m_heartbeatTimer) m_heartbeatTimer->stop();
    if (m_client)         m_client->disconnectDevice();
    emit workerStopped();
}

bool ModbusWorker::connectToPort() {
    if (!m_client) return false;

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
        emit connectionChanged(true);
        qInfo() << "ModbusWorker: connected to" << m_port;
        return true;
    }

    m_connected = false;
    emit connectionChanged(false);
    emit modbusError(QStringLiteral("Cannot connect to %1").arg(m_port));
    return false;
}

void ModbusWorker::tryReconnect() {
    if (!m_running) return;
    if (connectToPort()) {
        if (!m_pollTimer) {
            m_pollTimer = new QTimer(this);
            m_pollTimer->setInterval(m_defaultPollInterval);
            connect(m_pollTimer, &QTimer::timeout, this, &ModbusWorker::onPollTimer);
        }
        m_pollTimer->start();
        onPollTimer();
        return;
    }
    m_backoffMs = qMin(m_backoffMs * 2, kBackoffMax);
    QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
}

void ModbusWorker::onPollTimer() {
    if (!m_running) return;
    if (!m_connected || m_client->state() != QModbusDevice::ConnectedState) {
        if (m_pollTimer) m_pollTimer->stop();
        m_connected = false;
        emit connectionChanged(false);
        emit modbusError(QStringLiteral("Connection lost on %1").arg(m_port));
        m_backoffMs = 1000;
        QTimer::singleShot(m_backoffMs, this, &ModbusWorker::tryReconnect);
        return;
    }

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (const auto &cfg : std::as_const(m_sensors)) {
        if (!m_running) break;
        int sid = cfg["id"].toInt();
        if (now >= m_nextPollMs.value(sid, 0)) {
            pollSingle(cfg);
            int interval = cfg.value("poll_interval", 3).toInt() * 1000;
            m_nextPollMs[sid] = QDateTime::currentMSecsSinceEpoch() + interval;
        }
    }
}

void ModbusWorker::onHeartbeatTimer() {
    if (m_running)
        emit heartbeat("ModbusWorker");
}

void ModbusWorker::pollSingle(const QVariantMap &cfg) {
    QString stype = cfg.value("sensor_type", "ANALOG").toString();
    if (stype == "DI")      pollStandaloneDi(cfg);
    else if (stype == "DO") pollStandaloneDo(cfg);
    else                    pollAnalog(cfg);
}

void ModbusWorker::pollAnalog(const QVariantMap &cfg) {
    int sensorId    = cfg["id"].toInt();
    int slaveId     = cfg["slave_id"].toInt();
    int address     = cfg["register_address"].toInt();
    QString regType = cfg.value("register_type", "holding").toString();
    QString dataType= cfg.value("data_type", "int16").toString();
    QString dataFmt = cfg.value("data_format", "AB").toString();
    QString coeff   = cfg.value("coefficient", "{}").toString();

    // Determine QModbusDataUnit::RegisterType
    QModbusDataUnit::RegisterType regEnum = QModbusDataUnit::HoldingRegisters;
    int count = (dataType == "float32" || dataType == "int32" || dataType == "uint32") ? 2 : 1;

    if (regType == "input" || regType == "input register")
        regEnum = QModbusDataUnit::InputRegisters;
    else if (regType == "coil")
        regEnum = QModbusDataUnit::Coils;
    else if (regType == "discrete_input" || regType == "discrete input")
        regEnum = QModbusDataUnit::DiscreteInputs;

    QModbusDataUnit request(regEnum, address, count);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) {
        emit modbusError(QStringLiteral("No reply for sensor %1").arg(sensorId));
        return;
    }

    // Block until finished (we're on a worker thread, not the main thread)
    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error() != QModbusDevice::NoError) {
        emit modbusError(QStringLiteral("Modbus error sensor %1: %2")
                         .arg(sensorId).arg(reply->errorString()));
        reply->deleteLater();
        return;
    }

    QModbusDataUnit unit = reply->result();
    reply->deleteLater();

    double rawValue = 0.0;
    if (regEnum == QModbusDataUnit::Coils || regEnum == QModbusDataUnit::DiscreteInputs) {
        rawValue = unit.value(0) ? 1.0 : 0.0;
    } else {
        // Decode 16/32-bit register values
        QVector<quint16> regs;
        for (int i = 0; i < unit.valueCount(); ++i)
            regs.append(unit.value(i));
        rawValue = decodeRegisters(regs, dataType, dataFmt);
    }

    double value = Formula::applyFormula(rawValue, coeff);

    bool isAlarm = false;
    QString alarmType;
    auto minTh = cfg.value("min_threshold");
    auto maxTh = cfg.value("max_threshold");
    if (!minTh.isNull() && value <= minTh.toDouble()) { isAlarm = true; alarmType = "min"; }
    if (!maxTh.isNull() && value >= maxTh.toDouble()) {
        isAlarm = true;
        alarmType = alarmType.isEmpty() ? "max" : "min+max";
    }

    bool prevAlarm = m_alarmStates.value(sensorId, false);
    if (isAlarm != prevAlarm) {
        m_alarmStates[sensorId] = isAlarm;
        emit alarmChanged({{"sensor_id", sensorId}, {"is_alarm", isAlarm}, {"alarm_type", alarmType}});
        driveDoRelays(sensorId, isAlarm, alarmType);
    }

    QList<QVariantMap> diStates = readDiStates(sensorId);

    QVariantList doStatesList;
    for (const auto &ch : m_digitalIos.value(sensorId)) {
        if (ch.value("io_type") == "DO" && ch.value("active", true).toBool())
            doStatesList.append(QVariantMap{{"id", ch["id"]}, {"state", m_doStates.value(ch["id"].toInt(), false)}});
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
        {"alarm_type",  alarmType},
        {"di_states",   diStatesList},
        {"do_states",   doStatesList},
    });
}

void ModbusWorker::pollStandaloneDi(const QVariantMap &cfg) {
    int sensorId = cfg["id"].toInt();
    int slaveId  = cfg["slave_id"].toInt();
    int address  = cfg["register_address"].toInt();

    QModbusDataUnit request(QModbusDataUnit::DiscreteInputs, address, 1);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) { emit modbusError(QStringLiteral("DI no reply sensor %1").arg(sensorId)); return; }

    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    bool state = false;
    if (reply->error() == QModbusDevice::NoError)
        state = reply->result().value(0);
    reply->deleteLater();

    emit dataReady({
        {"sensor_id",   sensorId},
        {"raw_value",   state ? 1 : 0},
        {"value",       state ? 1 : 0},
        {"status",      QString("00")},
        {"recorded_at", QDateTime::currentDateTime().toString(Qt::ISODate)},
        {"is_alarm",    false},
        {"alarm_type",  QString()},
        {"di_states",   QVariantList{}},
    });
}

void ModbusWorker::pollStandaloneDo(const QVariantMap &cfg) {
    int sensorId = cfg["id"].toInt();
    int slaveId  = cfg["slave_id"].toInt();
    int address  = cfg["register_address"].toInt();

    QModbusDataUnit request(QModbusDataUnit::Coils, address, 1);
    auto *reply = m_client->sendReadRequest(request, slaveId);
    if (!reply) { emit modbusError(QStringLiteral("DO no reply sensor %1").arg(sensorId)); return; }

    QEventLoop loop;
    connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    bool state = false;
    if (reply->error() == QModbusDevice::NoError)
        state = reply->result().value(0);
    m_doStates[sensorId] = state;
    reply->deleteLater();

    emit dataReady({
        {"sensor_id",   sensorId},
        {"raw_value",   state ? 1 : 0},
        {"value",       state ? 1 : 0},
        {"status",      state ? QString("ON") : QString("OFF")},
        {"recorded_at", QDateTime::currentDateTime().toString(Qt::ISODate)},
        {"is_alarm",    false},
        {"alarm_type",  QString()},
        {"di_states",   QVariantList{}},
    });
}

void ModbusWorker::writeSingleCoil(int sensorId, bool value) {
    if (!m_client || m_client->state() != QModbusDevice::ConnectedState) {
        qWarning() << "writeSingleCoil: not connected";
        return;
    }
    for (const auto &cfg : std::as_const(m_sensors)) {
        if (cfg["id"].toInt() == sensorId) {
            int slaveId = cfg["slave_id"].toInt();
            int address = cfg["register_address"].toInt();
            QModbusDataUnit unit(QModbusDataUnit::Coils, address, 1);
            unit.setValue(0, value ? 1 : 0);
            auto *reply = m_client->sendWriteRequest(unit, slaveId);
            if (reply) {
                QEventLoop loop;
                connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
                loop.exec();
                m_doStates[sensorId] = value;
                reply->deleteLater();
            }
            return;
        }
    }
}

QList<QVariantMap> ModbusWorker::readDiStates(int sensorId) {
    QList<QVariantMap> results;
    if (!m_client || m_client->state() != QModbusDevice::ConnectedState)
        return results;

    for (const auto &ch : m_digitalIos.value(sensorId)) {
        if (ch.value("io_type") != "DI" || !ch.value("active", true).toBool())
            continue;
        int addr    = ch.value("address", ch.value("register_address", 0)).toInt();
        int slaveId = ch["slave_id"].toInt();

        QModbusDataUnit req(QModbusDataUnit::DiscreteInputs, addr, 1);
        auto *reply = m_client->sendReadRequest(req, slaveId);
        if (!reply) { results.append({{"id", ch["id"]}, {"label", ch["label"]}, {"di_type", ch["di_type"]}, {"state", QVariant()}}); continue; }

        QEventLoop loop;
        connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
        loop.exec();

        bool state = false;
        if (reply->error() == QModbusDevice::NoError) state = reply->result().value(0);
        reply->deleteLater();
        results.append({{"id", ch["id"]}, {"label", ch.value("label")}, {"di_type", ch.value("di_type")}, {"state", state}});
    }
    return results;
}

void ModbusWorker::driveDoRelays(int sensorId, bool isAlarm, const QString &alarmType) {
    if (!m_client || m_client->state() != QModbusDevice::ConnectedState) return;
    for (const auto &ch : m_digitalIos.value(sensorId)) {
        if (ch.value("io_type") != "DO" || !ch.value("active", true).toBool()) continue;
        int addr    = ch.value("address", ch.value("register_address", 0)).toInt();
        int slaveId = ch["slave_id"].toInt();
        bool coilValue = false;
        if (isAlarm) {
            if (ch.value("trigger_on_max", true).toBool() && alarmType.contains("max")) coilValue = true;
            if (ch.value("trigger_on_min", true).toBool() && alarmType.contains("min")) coilValue = true;
        }
        QModbusDataUnit unit(QModbusDataUnit::Coils, addr, 1);
        unit.setValue(0, coilValue ? 1 : 0);
        auto *reply = m_client->sendWriteRequest(unit, slaveId);
        if (reply) {
            QEventLoop loop;
            connect(reply, &QModbusReply::finished, &loop, &QEventLoop::quit);
            loop.exec();
            m_doStates[ch["id"].toInt()] = coilValue;
            reply->deleteLater();
        }
    }
}

// Register decoding helper (static free function)
static double decodeRegisters(const QVector<quint16> &regs, const QString &dataType, const QString &fmt) {
    if (regs.isEmpty()) return 0.0;
    QString dt = dataType.toLower();
    if (dt == "uint16") return regs[0];
    if (dt == "int16")  { qint16 v = static_cast<qint16>(regs[0]); return v; }

    if (regs.size() < 2) return regs[0];
    quint32 raw32 = 0;
    QString f = fmt.toUpper();
    if (f == "CDAB" || f == "BA") raw32 = (quint32(regs[1]) << 16) | regs[0];
    else                           raw32 = (quint32(regs[0]) << 16) | regs[1];

    if (dt == "uint32") return static_cast<double>(raw32);
    if (dt == "int32")  return static_cast<double>(static_cast<qint32>(raw32));
    if (dt == "float32") { float fv; memcpy(&fv, &raw32, sizeof(float)); return fv; }
    return regs[0];
}
