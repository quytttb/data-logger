#include "MonitorController.h"
#include "MonitorModel.h"
#include "network/modbus/ModbusTcpServerService.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/AppConfigDao.h"
#include "network/modbus/ModbusWorker.h"
#include "network/workers/DatabaseWorker.h"
#include <QElapsedTimer>
#include <QMutexLocker>
#include <QFile>
#include <QSet>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>

static MonitorController *g_monitorInstance = nullptr;

MonitorController *MonitorController::instance() { return g_monitorInstance; }

void MonitorController::setInstance(MonitorController *controller)
{
    g_monitorInstance = controller;
}

MonitorController *MonitorController::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(g_monitorInstance);
    QQmlEngine::setObjectOwnership(g_monitorInstance, QQmlEngine::CppOwnership);
    return g_monitorInstance;
}

// Colour palette for trending series and DI legend (M3 graph series — dark baseline).
static const QStringList kPalette = {
    "#4DB6AC", "#9FA8DA", "#4FC3F7", "#FFB74D",
    "#CE93D8", "#F48FB1", "#64B5F6", "#81C784"
};
static const QHash<QString, QString> kDiTypeNames = {
    {"00","Monitoring"},{"01","Calibrating"},{"02","Error"},{"03","Maintenance"}
};

MonitorController::MonitorController(MonitorModel *model,
                                      ModbusTcpServerService *modbusTcp,
                                      QObject *parent)
    : QObject(parent), m_model(model), m_mbtcp(modbusTcp) {

    m_heartbeats = {{"ModbusWorker", {}}, {"DatabaseWorker", {}}, {"FtpWorker", {}}};

    m_cpuTimer = new QTimer(this);
    m_cpuTimer->setInterval(10000);
    connect(m_cpuTimer, &QTimer::timeout, this, &MonitorController::readCpuTemp);
    m_cpuTimer->start();

    m_watchdogTimer = new QTimer(this);
    m_watchdogTimer->setInterval(5000);
    connect(m_watchdogTimer, &QTimer::timeout, this, &MonitorController::checkWatchdog);
}

bool MonitorController::hasActiveSensors() const {
    return m_model->rowCount() > 0;
}

QString MonitorController::statusText() const {
    if (m_statusTag == "monitoring")     return "Monitoring…";
    if (m_statusTag == "stopping")       return "Stopping…";
    if (m_statusTag == "connection_lost")return "Connection lost — retrying…";
    if (m_statusTag == "stopped")        return "Stopped";
    if (m_statusTag == "stopped_worker") return "Stopped (worker exited)";
    return "Ready";
}

void MonitorController::startPolling() {
    if (m_isPolling) return;

    auto db = Database::openConnection();
    AppConfigDao cfgDao(db);
    auto cfg = cfgDao.load();
    SensorDao sDao(db);
    auto allSensors = sDao.loadAll(/*activeOnly=*/true);
    auto allLinks   = sDao.loadAllLinks();
    db.close();

    if (allSensors.isEmpty()) {
        emit messageSent("Error", "No active sensors. Open Settings to add sensors.");
        return;
    }

    // Build digital link maps
    QHash<int, QVariantMap> digitalById;
    for (const auto &s : allSensors)
        digitalById[s.id] = {{"id", s.id}, {"name", s.name}, {"sensor_type", sensorTypeToString(s.sensorType)},
                              {"slave_id", s.slaveId}, {"register_address", s.registerAddress}, {"active", s.active}};

    QSet<int> linkedDigitalIds;
    for (const auto &l : allLinks)
        linkedDigitalIds.insert(l.digitalSensorId);

    QHash<int, QList<QVariantMap>> digitalIoMap;
    for (const auto &l : allLinks) {
        auto dsIt = digitalById.find(l.digitalSensorId);
        if (dsIt == digitalById.end()) continue;
        auto ds = *dsIt;
        if (!ds["active"].toBool()) continue;
        QVariantMap ch = ds;
        ch["io_type"]       = ds["sensor_type"];
        ch["label"]         = ds["name"];
        ch["di_type"]       = l.diType;
        ch["address"]       = ds["register_address"];
        ch["trigger_on_max"]= l.triggerOnMax;
        ch["trigger_on_min"]= l.triggerOnMin;
        digitalIoMap[l.analogSensorId].append(ch);
    }

    // Sensors for monitor cards (all)
    QList<QVariantMap> monitorSensorMaps;
    for (const auto &s : allSensors)
        monitorSensorMaps.append({{"id", s.id}, {"name", s.name}, {"unit", s.unit},
                                   {"sensor_type", sensorTypeToString(s.sensorType)}});
    m_model->loadSensors(monitorSensorMaps);
    clearReadingsCache();
    m_rtuConnected = false;

    // Poll sensors: analog + standalone DI/DO
    QList<QVariantMap> pollSensors;
    for (const auto &s : allSensors) {
        bool isAnalog = (s.sensorType == SensorType::Analog);
        bool isDigital= (s.sensorType == SensorType::DI || s.sensorType == SensorType::DO);
        bool isLinked = linkedDigitalIds.contains(s.id);
        if (isAnalog || (isDigital && !isLinked))
            pollSensors.append({
                {"id", s.id}, {"slave_id", s.slaveId}, {"register_address", s.registerAddress},
                {"register_type", s.registerType}, {"data_type", s.dataType},
                {"data_format", s.dataFormat}, {"coefficient", s.coefficient},
                {"poll_interval", s.pollInterval},
                {"min_threshold", s.minThreshold.has_value() ? QVariant(*s.minThreshold) : QVariant()},
                {"max_threshold", s.maxThreshold.has_value() ? QVariant(*s.maxThreshold) : QVariant()},
                {"sensor_type", sensorTypeToString(s.sensorType)},
            });
    }

    resetTrendBuffers(monitorSensorMaps);

    // Build DI legend
    QList<QVariantMap> linkedDi;
    for (const auto &l : allLinks) {
        auto it = digitalById.find(l.digitalSensorId);
        if (it == digitalById.end()) continue;
        if ((*it)["sensor_type"] == "DI" && (*it)["active"].toBool()) {
            auto m = *it;
            m["di_type"] = l.diType;
            linkedDi.append(m);
        }
    }
    QList<QVariantMap> linkMaps;
    for (const auto &l : allLinks)
        linkMaps.append({{"digital_sensor_id", l.digitalSensorId}, {"di_type", l.diType}});
    buildDiLegend(linkedDi, linkMaps);

    if (m_mbtcp) {
        QList<int> analogIds;
        QHash<int,int> diMap, doMap;
        for (const auto &s : allSensors) {
            if (s.sensorType == SensorType::Analog) analogIds.append(s.id);
            if (s.sensorType == SensorType::DI) diMap[s.id] = s.registerAddress;
            if (s.sensorType == SensorType::DO) doMap[s.id] = s.registerAddress;
        }
        m_mbtcp->setSensorMap(analogIds);
        m_mbtcp->setDiDoMap(diMap, doMap);
        m_mbtcp->setLoggerStatus(true, false);
    }

    // Start DatabaseWorker
    auto *dbWorker = new DatabaseWorker();
    m_dbThread = new QThread(this);
    dbWorker->moveToThread(m_dbThread);
    connect(m_dbThread, &QThread::started, dbWorker, &DatabaseWorker::start);
    connect(dbWorker, &DatabaseWorker::workerStopped, m_dbThread, &QThread::quit);
    connect(dbWorker, &DatabaseWorker::dbError,       this, &MonitorController::onDbError);
    connect(dbWorker, &DatabaseWorker::recordsSaved,  this, &MonitorController::onRecordsSaved);
    connect(dbWorker, &DatabaseWorker::heartbeat,     this, &MonitorController::registerHeartbeat);
    m_dbWorker = dbWorker;

    // Start ModbusWorker
    auto *mbWorker = new ModbusWorker();
    mbWorker->configure(cfg.serialPort, cfg.serialBaudrate, cfg.serialBytesize,
                        cfg.serialParity, cfg.serialStopbits, 1, cfg.pollInterval);
    mbWorker->setSensors(pollSensors);
    mbWorker->setDigitalIos(digitalIoMap);

    m_modbusThread = new QThread(this);
    mbWorker->moveToThread(m_modbusThread);
    connect(m_modbusThread, &QThread::started,        mbWorker, &ModbusWorker::start);
    connect(mbWorker, &ModbusWorker::workerStopped,   this, &MonitorController::onModbusStopped);
    connect(mbWorker, &ModbusWorker::dataReady,       this, &MonitorController::onDataReady);
    connect(mbWorker, &ModbusWorker::modbusError,     this, &MonitorController::onModbusError);
    connect(mbWorker, &ModbusWorker::connectionChanged, this, &MonitorController::onConnectionChanged);
    connect(mbWorker, &ModbusWorker::alarmChanged,    this, &MonitorController::onAlarmChanged);
    connect(mbWorker, &ModbusWorker::heartbeat,       this, &MonitorController::registerHeartbeat);
    m_modbusWorker = mbWorker;

    m_dbThread->start();
    m_modbusThread->start();
    m_watchdogTimer->start();

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (auto &hb : m_heartbeats) hb.lastTime = now / 1000.0;

    m_isPolling  = true;
    m_errorCount = 0;
    applyStatus("monitoring", STATUS_OK);
    emit pollingChanged();
    emit errorCountChanged();
    qInfo() << "Polling started:" << allSensors.size() << "sensors";
}

void MonitorController::stopPolling() {
    if (!m_isPolling || m_isStopping) return;
    m_watchdogTimer->stop();
    m_isStopping = true;
    applyStatus("stopping", STATUS_IDLE);
    emit stoppingChanged();

    if (m_modbusWorker) QMetaObject::invokeMethod(m_modbusWorker, "stop");
    if (m_dbWorker)     QMetaObject::invokeMethod(m_dbWorker, "stop");
    if (m_modbusThread) m_modbusThread->quit();
    if (m_dbThread)     m_dbThread->quit();

    checkThreadsFinished();
}

void MonitorController::checkThreadsFinished() {
    bool mb = (!m_modbusThread || !m_modbusThread->isRunning());
    bool db = (!m_dbThread     || !m_dbThread->isRunning());
    if (mb && db) { finalizeStop(); return; }
    QTimer::singleShot(50, this, &MonitorController::checkThreadsFinished);
}

void MonitorController::finalizeStop() {
    m_modbusWorker = nullptr;
    m_dbWorker     = nullptr;
    if (m_modbusThread) { m_modbusThread->deleteLater(); m_modbusThread = nullptr; }
    if (m_dbThread)     { m_dbThread->deleteLater();     m_dbThread = nullptr; }
    m_isPolling  = false;
    m_isStopping = false;
    if (m_mbtcp) m_mbtcp->setLoggerStatus(false, false);
    applyStatus("stopped", STATUS_IDLE);
    emit pollingChanged();
    emit stoppingChanged();
    m_model->setAllStatus("---");
    qInfo() << "Polling stopped.";
}

void MonitorController::stopPollingSync() {
    if (!m_isPolling) return;
    m_watchdogTimer->stop();
    if (m_modbusWorker) QMetaObject::invokeMethod(m_modbusWorker, "stop");
    if (m_dbWorker)     QMetaObject::invokeMethod(m_dbWorker, "stop");
    if (m_modbusThread) { m_modbusThread->quit(); m_modbusThread->wait(3000); }
    if (m_dbThread)     { m_dbThread->quit();     m_dbThread->wait(3000); }
    m_isPolling = false; m_isStopping = false;
    if (m_mbtcp) m_mbtcp->setLoggerStatus(false, false);
}

void MonitorController::refreshSensors() {
    if (m_isPolling) return;
    auto db = Database::openConnection();
    SensorDao dao(db);
    auto sensors = dao.loadAll(true);
    db.close();

    QList<QVariantMap> maps;
    for (const auto &s : sensors)
        maps.append({{"id", s.id}, {"name", s.name}, {"unit", s.unit},
                      {"sensor_type", sensorTypeToString(s.sensorType)}});
    m_model->loadSensors(maps);
    resetTrendBuffers(maps);
    emit activeSensorsChanged();
}

void MonitorController::registerHeartbeat(const QString &workerName) {
    auto it = m_heartbeats.find(workerName);
    if (it != m_heartbeats.end()) {
        it->lastTime = QDateTime::currentMSecsSinceEpoch() / 1000.0;
        it->misses   = 0;
    }
}

void MonitorController::writeDo(int sensorId, bool value) {
    if (!m_isPolling || !m_modbusWorker) return;
    QMetaObject::invokeMethod(m_modbusWorker, "writeSingleCoil",
                              Q_ARG(int, sensorId), Q_ARG(bool, value));
}

QVariantList MonitorController::getTrendBuffer(int sensorId) const {
    auto it = m_trendBuffers.find(sensorId);
    if (it == m_trendBuffers.end()) return {};
    QVariantList result;
    for (const auto &[ts, val] : it.value())
        result.append(QVariantMap{{"x", ts}, {"y", val}});
    return result;
}

QVariantMap MonitorController::readingsSnapshot() const {
    QMutexLocker lock(&m_readingsMutex);
    QVariantList sensors;
    for (auto it = m_readingsCache.cbegin(); it != m_readingsCache.cend(); ++it)
        sensors.append(it.value());
    return {{"ok", true}, {"polling", m_isPolling},
            {"rtu_connected", m_rtuConnected}, {"sensors", sensors}};
}

// ── Internal slots ─────────────────────────────────────────────────────────

void MonitorController::onDataReady(QVariantMap payload) {
    if (!m_isPolling || m_isStopping) return;

    QVariantList rawDi = payload.value("di_states").toList();
    QVariantList coloredDi;
    for (const auto &diV : rawDi) {
        QVariantMap di = diV.toMap();
        if (di.value("state").toBool()) {
            QString code  = di.value("di_type").toString();
            QString label = kDiTypeNames.value(code, di.value("label").toString());
            QString color = m_diLabelToColor.value(label, QStringLiteral("#938F99"));
            coloredDi.append(QVariantMap{{"label", label}, {"color", color}});
        }
    }

    int sensorId    = payload["sensor_id"].toInt();
    double value    = payload["value"].toDouble();
    double rawValue = payload["raw_value"].toDouble();
    QString recAt   = payload["recorded_at"].toString();
    bool isAlarm    = payload.value("is_alarm", false).toBool();
    QString alType  = payload.value("alarm_type").toString();

    m_model->updateValue(sensorId, value, rawValue, recAt, isAlarm, alType, coloredDi);
    cacheReading(payload);
    syncLinkedDigitalCards(payload);
    pushTrendPoint(sensorId, recAt, value);

    if (m_dbWorker)
        QMetaObject::invokeMethod(m_dbWorker, "enqueue", Q_ARG(QVariantMap, payload));

    if (m_mbtcp) {
        m_mbtcp->updateValue(sensorId, float(value), isAlarm);
        for (const auto &diV : rawDi) {
            auto di = diV.toMap();
            if (!di.value("state").isNull())
                m_mbtcp->updateDi(di["id"].toInt(), di["state"].toBool());
        }
        for (const auto &doV : payload.value("do_states").toList()) {
            auto doM = doV.toMap();
            if (!doM.value("state").isNull())
                m_mbtcp->updateDo(doM["id"].toInt(), doM["state"].toBool());
        }
    }
}

void MonitorController::onModbusError(QString msg) {
    if (m_isStopping) return;
    ++m_errorCount;
    emit errorCountChanged();
    qWarning() << "Modbus error #" << m_errorCount << ":" << msg;
}

void MonitorController::onConnectionChanged(bool connected) {
    m_rtuConnected = connected;
    if (m_mbtcp) m_mbtcp->setLoggerStatus(m_isPolling, connected);
    if (m_isStopping) return;
    if (connected) applyStatus("monitoring", STATUS_OK);
    else { applyStatus("connection_lost", STATUS_ERR); m_model->setAllStatus("ERR"); markReadingsCacheErr(); }
}

void MonitorController::onModbusStopped() {
    if (m_modbusThread) m_modbusThread->quit();
    if (m_isStopping) return;
    if (m_isPolling) {
        m_isStopping = true;
        applyStatus("stopped_worker", STATUS_ERR);
        emit stoppingChanged();
        if (m_dbWorker) QMetaObject::invokeMethod(m_dbWorker, "stop");
        if (m_dbThread) m_dbThread->quit();
        checkThreadsFinished();
    }
}

void MonitorController::onDbError(QString msg) { qCritical() << "DB error:" << msg; }
void MonitorController::onRecordsSaved(int count) { emit recordsCommitted(count); }
void MonitorController::onAlarmChanged(QVariantMap info) {
    qInfo() << "Alarm changed sensor=" << info["sensor_id"].toInt()
            << "alarm=" << info["is_alarm"].toBool();
}

void MonitorController::readCpuTemp() {
    QFile f("/sys/class/thermal/thermal_zone0/temp");
    if (f.open(QIODevice::ReadOnly)) {
        float t = f.readAll().trimmed().toFloat() / 1000.0f;
        if (m_cpuTemp != t) { m_cpuTemp = t; emit cpuTempChanged(); }
    }
}

void MonitorController::checkWatchdog() {
    double now = QDateTime::currentMSecsSinceEpoch() / 1000.0;
    QStringList misses;
    for (auto it = m_heartbeats.begin(); it != m_heartbeats.end(); ++it) {
        const QString &wn = it.key();
        double limit = (wn == "FtpWorker") ? 120.0 : 6.0;
        if (it->lastTime > 0 && (now - it->lastTime) > limit) {
            it->misses++;
            if (it->misses > 3) misses << wn;
        } else {
            it->misses = 0;
        }
    }
    if (!misses.isEmpty()) {
        m_watchdogStatus = "ERR: " + misses.join(',');
        for (const auto &m : misses) emit watchdogAlert("Worker dead: " + m);
        if ((misses.contains("ModbusWorker") || misses.contains("DatabaseWorker")) && m_isPolling) {
            stopPollingSync();
            QTimer::singleShot(2000, this, &MonitorController::startPolling);
        }
    } else {
        m_watchdogStatus = "OK";
    }
    emit watchdogChanged();
}

// ── Helpers ────────────────────────────────────────────────────────────────

void MonitorController::applyStatus(const QString &tag, int mode) {
    m_statusTag = tag;
    if (mode >= 0) m_statusMode = mode;
    emit statusChanged();
}

void MonitorController::resetTrendBuffers(const QList<QVariantMap> &sensors) {
    m_trendBuffers.clear();
    m_analogSensors.clear();
    for (int i = 0; i < sensors.size(); ++i) {
        const auto &s = sensors[i];
        int id = s["id"].toInt();
        m_trendBuffers[id] = {};
        m_analogSensors.append(QVariantMap{
            {"id", id}, {"name", s["name"]}, {"unit", s.value("unit","")},
            {"color", kPalette[i % kPalette.size()]},
            {"sensorType", s.value("sensor_type","ANALOG")},
        });
    }
    emit analogSensorsListChanged();
}

void MonitorController::pushTrendPoint(int sensorId, const QString &recAt, double value) {
    auto it = m_trendBuffers.find(sensorId);
    if (it == m_trendBuffers.end()) return;
    QDateTime dt = QDateTime::fromString(recAt, Qt::ISODate);
    double tsMs = dt.isValid() ? dt.toMSecsSinceEpoch() : QDateTime::currentMSecsSinceEpoch();
    auto &buf = it.value();
    buf.push_back({tsMs, value});
    if (buf.size() > static_cast<size_t>(kTrendBufferSize)) buf.pop_front();
    emit newDataPoint(sensorId, tsMs, value);
}

void MonitorController::buildDiLegend(const QList<QVariantMap> &diSensors,
                                        const QList<QVariantMap> &links) {
    QHash<int, QString> diTypeMap;
    for (const auto &l : links)
        diTypeMap.insert(l["digital_sensor_id"].toInt(), l["di_type"].toString());

    QStringList seenLabels;
    for (const auto &s : diSensors) {
        QString code  = diTypeMap.value(s["id"].toInt());
        QString label = kDiTypeNames.value(code, s["name"].toString());
        if (!label.isEmpty() && !seenLabels.contains(label))
            seenLabels << label;
    }

    m_diLabelToColor.clear();
    m_diLegend.clear();
    for (int i = 0; i < seenLabels.size(); ++i) {
        QString color = kPalette[i % kPalette.size()];
        m_diLabelToColor[seenLabels[i]] = color;
        m_diLegend.append(QVariantMap{{"label", seenLabels[i]}, {"color", color}});
    }
    emit diLegendChanged();
}

void MonitorController::syncLinkedDigitalCards(const QVariantMap &payload) {
    QString recAt = payload.value("recorded_at").toString();
    for (const auto &v : payload.value("di_states").toList()) {
        auto di = v.toMap();
        if (!di.value("state").isNull())
            m_model->updateValue(di["id"].toInt(), di["state"].toBool() ? 1.0 : 0.0, 0, recAt);
    }
    for (const auto &v : payload.value("do_states").toList()) {
        auto doM = v.toMap();
        if (!doM.value("state").isNull())
            m_model->updateValue(doM["id"].toInt(), doM["state"].toBool() ? 1.0 : 0.0, 0, recAt);
    }
}

void MonitorController::cacheReading(const QVariantMap &payload) {
    int sid = payload["sensor_id"].toInt();
    QMutexLocker lock(&m_readingsMutex);
    m_readingsCache[sid] = {
        {"sensor_id", sid},
        {"value",     payload.value("value")},
        {"is_alarm",  payload.value("is_alarm", false)},
        {"alarm_type",payload.value("alarm_type")},
        {"status",    payload.value("status")},
        {"recorded_at", payload.value("recorded_at")},
        {"valid", true},
    };
}

void MonitorController::markReadingsCacheErr() {
    QMutexLocker lock(&m_readingsMutex);
    for (auto &v : m_readingsCache) {
        v["status"] = "ERR";
    }
}

void MonitorController::clearReadingsCache() {
    QMutexLocker lock(&m_readingsMutex);
    m_readingsCache.clear();
}
