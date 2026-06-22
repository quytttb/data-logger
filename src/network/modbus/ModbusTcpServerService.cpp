#include "ModbusTcpServerService.h"
#include "utils/LanIp.h"
#include <QModbusDataUnit>
#include <QDateTime>
#include <QMutexLocker>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <cstring>
#include <algorithm>
#include <utility>

IMPLEMENT_QML_SINGLETON(ModbusTcpServerService)

ModbusTcpServerService::ModbusTcpServerService(QObject *parent) : QObject(parent) {}

ModbusTcpServerService::~ModbusTcpServerService() {
    stop();
}

void ModbusTcpServerService::start(const QString &bind, int port, int unitId) {
    if (m_state == STATE_LISTENING || m_state == STATE_STARTING) {
        if (m_bind == bind && m_port == port && m_unitId == unitId) return;
        stop();
    }

    m_bind   = bind.isEmpty() ? "0.0.0.0" : bind;
    m_port   = port;
    m_unitId = unitId;
    setState(STATE_STARTING);

    if (m_server) { m_server->disconnectDevice(); delete m_server; }
    m_server = new QModbusTcpServer(this);

    // Build initial data map
    QMap<QModbusDataUnit::RegisterType, QModbusDataUnit> regMap;
    regMap[QModbusDataUnit::Coils]           = QModbusDataUnit(QModbusDataUnit::Coils,           0, kBitBlockSize);
    regMap[QModbusDataUnit::DiscreteInputs]  = QModbusDataUnit(QModbusDataUnit::DiscreteInputs,  0, kBitBlockSize);
    regMap[QModbusDataUnit::HoldingRegisters]= QModbusDataUnit(QModbusDataUnit::HoldingRegisters, 0, kHrTotal);
    regMap[QModbusDataUnit::InputRegisters]  = QModbusDataUnit(QModbusDataUnit::InputRegisters,   0, 16);
    m_server->setMap(regMap);

    // Write map version
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_VERSION, 1);

    m_server->setConnectionParameter(QModbusDevice::NetworkAddressParameter, m_bind);
    m_server->setConnectionParameter(QModbusDevice::NetworkPortParameter,    m_port);
    m_server->setServerAddress(m_unitId);

    if (!m_server->connectDevice()) {
        setState(STATE_ERROR, m_server->errorString());
        qCritical() << "ModbusTcpServer failed to start:" << m_server->errorString();
        return;
    }

    setState(STATE_LISTENING);
    qInfo() << "Modbus TCP server listening" << m_bind << ":" << m_port << "unit=" << m_unitId;
}

void ModbusTcpServerService::stop() {
    if (m_server) {
        m_server->disconnectDevice();
        m_server->deleteLater();
        m_server = nullptr;
    }
    setState(STATE_STOPPED);
}

QString ModbusTcpServerService::listeningEndpoint() const {
    if (m_state != STATE_LISTENING) return {};
    return QStringLiteral("%1:%2").arg(m_bind).arg(m_port);
}

QString ModbusTcpServerService::primaryIp() const {
    return LanIp::primaryLanIp();
}

void ModbusTcpServerService::setSensorMap(const QList<int> &sensorIds) {
    QMutexLocker lock(&m_mutex);
    m_sensorSlots.clear();
    for (int i = 0; i < sensorIds.size(); ++i)
        m_sensorSlots[sensorIds[i]] = i;

    if (!m_server) return;
    // Clear sensor block
    for (int i = kSensorBase; i < kHrTotal; ++i)
        m_server->setData(QModbusDataUnit::HoldingRegisters, i, 0);
    // Write sensor IDs
    for (auto it = m_sensorSlots.cbegin(); it != m_sensorSlots.cend(); ++it) {
        int base = kSensorBase + it.value() * kSensorStride;
        m_server->setData(QModbusDataUnit::HoldingRegisters, base, quint16(it.key() & 0xFFFF));
    }
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_SENSOR_COUNT, quint16(m_sensorSlots.size()));
}

void ModbusTcpServerService::clearSensorMap() {
    setSensorMap({});
}

void ModbusTcpServerService::setDiDoMap(const QHash<int,int> &diMap, const QHash<int,int> &doMap) {
    QMutexLocker lock(&m_mutex);
    m_diMap = diMap;
    m_doMap = doMap;

    int ndi = 0;
    for (auto v : diMap) if (v + 1 > ndi) ndi = v + 1;
    int ndo = 0;
    for (auto v : doMap) if (v + 1 > ndo) ndo = v + 1;

    m_diBits.assign(ndi, false);
    m_doBits.assign(ndo, false);
    if (m_server) {
        m_server->setData(QModbusDataUnit::HoldingRegisters, HR_NDI, quint16(ndi));
        m_server->setData(QModbusDataUnit::HoldingRegisters, HR_NDO, quint16(ndo));
    }
}

void ModbusTcpServerService::updateValue(int sensorId, float value, bool isAlarm) {
    QMutexLocker lock(&m_mutex);
    auto it = m_sensorSlots.find(sensorId);
    if (it == m_sensorSlots.end() || !m_server) return;

    int base = kSensorBase + it.value() * kSensorStride;
    quint16 hi, lo;
    packFloat32(value, hi, lo);
    quint32 ts = static_cast<quint32>(QDateTime::currentSecsSinceEpoch());
    quint16 tsHi, tsLo;
    packU32(ts, tsHi, tsLo);

    quint16 flags = SF_VALID | (isAlarm ? SF_ALARM : 0);
    m_server->setData(QModbusDataUnit::HoldingRegisters, base + 1, flags);
    m_server->setData(QModbusDataUnit::HoldingRegisters, base + 2, hi);
    m_server->setData(QModbusDataUnit::HoldingRegisters, base + 3, lo);
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_TS_HI, tsHi);
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_TS_LO, tsLo);
    refreshAnyAlarmBit();
}

void ModbusTcpServerService::updateDi(int sensorId, bool state) {
    QMutexLocker lock(&m_mutex);
    auto it = m_diMap.find(sensorId);
    if (it == m_diMap.end() || it.value() >= m_diBits.size()) return;
    m_diBits[it.value()] = state;
    if (m_server)
        m_server->setData(QModbusDataUnit::DiscreteInputs, it.value(), state ? 1 : 0);
}

void ModbusTcpServerService::updateDo(int sensorId, bool state) {
    QMutexLocker lock(&m_mutex);
    auto it = m_doMap.find(sensorId);
    if (it == m_doMap.end() || it.value() >= m_doBits.size()) return;
    m_doBits[it.value()] = state;
    if (m_server)
        m_server->setData(QModbusDataUnit::Coils, it.value(), state ? 1 : 0);
}

void ModbusTcpServerService::setLoggerStatus(bool polling, bool rtuConnected) {
    QMutexLocker lock(&m_mutex);
    if (!m_server) return;
    quint16 cur = 0;
    m_server->data(QModbusDataUnit::HoldingRegisters, HR_STATUS, &cur);
    quint16 flags = cur & FLAG_ALARM; // preserve alarm bit
    if (polling)      flags |= FLAG_POLLING;
    if (rtuConnected) flags |= FLAG_RTU;
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_STATUS, flags);
    if (!polling) {
        // Mark all sensors stale
        for (auto slot : std::as_const(m_sensorSlots)) {
            int addr = kSensorBase + slot * kSensorStride + 1;
            quint16 f = 0;
            m_server->data(QModbusDataUnit::HoldingRegisters, addr, &f);
            m_server->setData(QModbusDataUnit::HoldingRegisters, addr, f | SF_STALE);
        }
    }
}

void ModbusTcpServerService::refreshAnyAlarmBit() {
    if (!m_server) return;
    bool anyAlarm = false;
    for (auto slot : std::as_const(m_sensorSlots)) {
        quint16 f = 0;
        m_server->data(QModbusDataUnit::HoldingRegisters, kSensorBase + slot * kSensorStride + 1, &f);
        if (f & SF_ALARM) { anyAlarm = true; break; }
    }
    quint16 cur = 0;
    m_server->data(QModbusDataUnit::HoldingRegisters, HR_STATUS, &cur);
    quint16 next = (cur & ~FLAG_ALARM) | (anyAlarm ? FLAG_ALARM : 0);
    m_server->setData(QModbusDataUnit::HoldingRegisters, HR_STATUS, next);
}

void ModbusTcpServerService::packFloat32(float v, quint16 &hi, quint16 &lo) const {
    quint32 raw; memcpy(&raw, &v, sizeof(float));
    hi = quint16(raw >> 16); lo = quint16(raw & 0xFFFF);
}
void ModbusTcpServerService::packU32(quint32 v, quint16 &hi, quint16 &lo) const {
    hi = quint16(v >> 16); lo = quint16(v & 0xFFFF);
}

void ModbusTcpServerService::setState(const QString &s, const QString &err) {
    bool cs = (s != m_state), ce = (err != m_lastError);
    m_state = s; m_lastError = err;
    if (cs) emit stateChanged();
    if (ce) emit lastErrorChanged();
}
