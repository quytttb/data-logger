#include "RestApiService.h"
#include "utils/LanIp.h"
#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/SensorDao.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QHostAddress>
#include <QMutexLocker>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <QTcpServer>

IMPLEMENT_QML_SINGLETON(RestApiService)

RestApiService::RestApiService(QObject *parent) : QObject(parent) {}

void RestApiService::setToken(const QString &token) {
    QMutexLocker lock(&m_mutex);
    m_token = token;
}

void RestApiService::setReadingsProvider(std::function<QVariantMap()> provider) {
    QMutexLocker lock(&m_mutex);
    m_readingsProvider = std::move(provider);
}

void RestApiService::start(const QString &bind, int port, const QString &token) {
    if (isListening()) stop();

    m_bind  = bind.isEmpty() ? kDefaultBind : bind;
    m_port  = port;
    setToken(token);

    if (m_tcpServer) { delete m_tcpServer; m_tcpServer = nullptr; }
    if (m_server)    { delete m_server;    m_server    = nullptr; }

    m_tcpServer = new QTcpServer(this);
    QHostAddress addr = (m_bind == kDefaultBind) ? QHostAddress::Any : QHostAddress(m_bind);
    if (!m_tcpServer->listen(addr, quint16(m_port))) {
        setState(STATE_ERROR, QStringLiteral("Cannot bind %1:%2").arg(m_bind).arg(m_port));
        qCritical() << "RestApiService: cannot listen on" << m_bind << m_port;
        return;
    }

    m_server = new QHttpServer(this);
    m_server->bind(m_tcpServer);
    setupRoutes();

    setState(STATE_LISTENING);
    qInfo() << "REST API listening" << m_bind << ":" << m_port;
}

void RestApiService::stop() {
    if (m_server)    { m_server->deleteLater();    m_server    = nullptr; }
    if (m_tcpServer) { m_tcpServer->deleteLater(); m_tcpServer = nullptr; }
    setState(STATE_STOPPED);
}

QString RestApiService::listeningEndpoint() const {
    if (!isListening()) return {};
    return QStringLiteral("%1:%2").arg(m_bind).arg(m_port);
}

QString RestApiService::primaryIp() const {
    return LanIp::primaryLanIp();
}

bool RestApiService::checkAuth(const QHttpServerRequest &req) const {
    QMutexLocker lock(&m_mutex);
    if (m_token.isEmpty()) return true;
    auto authHeader = req.value("Authorization");
    return authHeader == QStringLiteral("Bearer %1").arg(m_token).toLatin1();
}

void RestApiService::setupRoutes() {
    // GET /api/v1/readings
    m_server->route("/api/v1/readings", QHttpServerRequest::Method::Get,
        [this](const QHttpServerRequest &req) -> QHttpServerResponse {
            if (!checkAuth(req))
                return QHttpServerResponse(R"({"error":"Unauthorized"})",
                                           QHttpServerResponse::StatusCode::Unauthorized);
            QVariantMap snapshot;
            {
                QMutexLocker lock(&m_mutex);
                if (m_readingsProvider) snapshot = m_readingsProvider();
            }
            QJsonDocument doc = QJsonDocument::fromVariant(snapshot);
            QHttpServerResponse resp("application/json", doc.toJson(QJsonDocument::Compact));
            return resp;
        });

    // GET /api/v1/config
    m_server->route("/api/v1/config", QHttpServerRequest::Method::Get,
        [this](const QHttpServerRequest &req) -> QHttpServerResponse {
            if (!checkAuth(req))
                return QHttpServerResponse(R"({"error":"Unauthorized"})",
                                           QHttpServerResponse::StatusCode::Unauthorized);
            ScopedDbConnection db;
            AppConfigDao dao(db);
            auto cfg = dao.load();
            SensorDao sensorDao(db);
            auto sensors = sensorDao.loadAll();

            QJsonObject obj;
            obj["station_code"] = cfg.stationCode;
            obj["station_name"] = cfg.stationName;
            obj["poll_interval"]= cfg.pollInterval;
            obj["serial_port"]  = cfg.serialPort;
            obj["serial_baudrate"] = cfg.serialBaudrate;
            obj["config_revision"] = cfg.configRevision;

            // Per-sensor config. data-logger (edge) is the source of truth;
            // Central consumes these read-only (e.g. `decimals` display precision).
            QJsonArray sensorArr;
            for (const auto &s : sensors) {
                QJsonObject so;
                so["id"]          = s.id;
                so["name"]        = s.name;
                so["unit"]        = s.unit;
                so["sensor_type"] = sensorTypeToString(s.sensorType);
                so["decimals"]    = s.decimals;
                so["report_index"]= s.reportIndex;
                // Modbus identity so Central can join FC03/FC02/FC01 samples:
                // ANALOG → FC03 sensor_id == id; DI/DO → FC02/FC01 bit index == register_address.
                so["slave_id"]        = s.slaveId;
                so["register_address"]= s.registerAddress;
                sensorArr.append(so);
            }
            obj["sensors"] = sensorArr;

            QHttpServerResponse resp("application/json",
                                     QJsonDocument(obj).toJson(QJsonDocument::Compact));
            return resp;
        });

    // POST /api/v1/config
    m_server->route("/api/v1/config", QHttpServerRequest::Method::Post,
        [this](const QHttpServerRequest &req) -> QHttpServerResponse {
            if (!checkAuth(req))
                return QHttpServerResponse(R"({"error":"Unauthorized"})",
                                           QHttpServerResponse::StatusCode::Unauthorized);

            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(req.body(), &err);
            if (err.error != QJsonParseError::NoError || !doc.isObject())
                return QHttpServerResponse(R"({"error":"Invalid JSON"})",
                                           QHttpServerResponse::StatusCode::BadRequest);

            ScopedDbConnection db;
            AppConfigDao dao(db);
            auto cfg = dao.load();
            QJsonObject body = doc.object();

            // Apply writable fields
            if (body.contains("station_code"))   cfg.stationCode    = body["station_code"].toString();
            if (body.contains("station_name"))   cfg.stationName    = body["station_name"].toString();
            if (body.contains("poll_interval"))  cfg.pollInterval   = body["poll_interval"].toInt();
            if (body.contains("serial_port"))    cfg.serialPort     = body["serial_port"].toString();
            if (body.contains("serial_baudrate"))cfg.serialBaudrate = body["serial_baudrate"].toInt();

            cfg.configRevision++;
            dao.save(cfg);
            int rev = cfg.configRevision;

            emit configApplied(rev);

            QJsonObject resp;
            resp["ok"] = true;
            resp["config_revision"] = rev;
            return QHttpServerResponse("application/json",
                                       QJsonDocument(resp).toJson(QJsonDocument::Compact));
        });
}

void RestApiService::setState(const QString &s, const QString &err) {
    bool cs = (s != m_state), ce = (err != m_lastError);
    m_state = s; m_lastError = err;
    if (cs) emit stateChanged();
    if (ce) emit lastErrorChanged();
}
