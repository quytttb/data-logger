#include "RestApiService.h"
#include "utils/network/LanIp.h"
#include "data/db/Database.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/SensorDao.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QHostAddress>
#include <QMutexLocker>
#include <QRegularExpression>
#include <QSet>
#include <QDateTime>
#include <QDebug>
#include <QQmlEngine>
#include <QJSEngine>
#include <QTcpServer>

#include <cstring>

IMPLEMENT_QML_SINGLETON(RestApiService)

namespace {

// Constant-time comparison to avoid leaking the token prefix via timing.
bool timingSafeEquals(const QByteArray &a, const QByteArray &b) {
    if (a.size() != b.size()) return false;
    unsigned char diff = 0;
    for (int i = 0; i < a.size(); ++i)
        diff |= static_cast<unsigned char>(a.at(i) ^ b.at(i));
    return diff == 0;
}

bool isValidSerialPort(const QString &port) {
    // Whitelist: only /dev/tty* device paths (USB/AMA/ttyS0). An empty value
    // keeps the current config untouched (field is optional on POST).
    static const QRegularExpression re(QStringLiteral("^/dev/tty[A-Za-z0-9_.-]{1,64}$"));
    return re.match(port).hasMatch();
}

} // namespace

RestApiService::RestApiService(QObject *parent) : QObject(parent) {}

void RestApiService::setToken(const QString &token) {
    QMutexLocker lock(&m_mutex);
    m_token = token;
}

void RestApiService::setReadingsProvider(std::function<QVariantMap()> provider) {
    QMutexLocker lock(&m_mutex);
    m_readingsProvider = std::move(provider);
}

void RestApiService::setHealthProvider(std::function<QVariantMap()> provider) {
    QMutexLocker lock(&m_mutex);
    m_healthProvider = std::move(provider);
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
    // SECURITY: with no token configured the endpoint must be closed, not open —
    // otherwise anyone on the LAN can read/modify the device config.
    if (m_token.isEmpty()) return false;
    const QByteArray provided = req.value("Authorization");
    const QByteArray expected = QStringLiteral("Bearer %1").arg(m_token).toLatin1();
    return timingSafeEquals(provided, expected);
}

bool RestApiService::checkRateLimit(const QString &ip) {
    // Fixed-window 1 giây: đơn giản, đủ cho LAN nội bộ (Central Logger poll
    // ~0.3 req/s; headroom 10 req/s). Vượt ngưỡng → 429, KHÔNG khóa IP để
    // không tự lock-out khi debug.
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    QMutexLocker lock(&m_mutex);
    if (m_rateBuckets.size() > 256)
        m_rateBuckets.clear(); // chống phình bảng khi nhiều IP lạ quét
    auto &bucket = m_rateBuckets[ip];
    if (nowMs - bucket.first >= 1000) {
        bucket.first  = nowMs;
        bucket.second = 0;
    }
    return ++bucket.second <= kRateLimitPerSec;
}

void RestApiService::setupRoutes() {
    // GET /api/v1/health — KHÔNG cần auth (Central Logger + agent debug gọi
    // nhanh không cần token). Chỉ trả thông tin tối thiểu, không lộ secret.
    m_server->route("/api/v1/health", QHttpServerRequest::Method::Get,
        [this](const QHttpServerRequest &req) -> QHttpServerResponse {
            if (!checkRateLimit(req.remoteAddress().toString()))
                return QHttpServerResponse(R"({"error":"Too Many Requests"})",
                                           QHttpServerResponse::StatusCode::TooManyRequests);
            QVariantMap snapshot;
            {
                QMutexLocker lock(&m_mutex);
                if (m_healthProvider) snapshot = m_healthProvider();
            }
            QJsonObject obj = QJsonObject::fromVariantMap(snapshot);
            obj["status"] = obj.value("crypto_degraded").toBool()
                                ? QStringLiteral("degraded")
                                : QStringLiteral("ok");
            QHttpServerResponse resp("application/json",
                                     QJsonDocument(obj).toJson(QJsonDocument::Compact));
            return resp;
        });

    // GET /api/v1/readings
    m_server->route("/api/v1/readings", QHttpServerRequest::Method::Get,
        [this](const QHttpServerRequest &req) -> QHttpServerResponse {
            if (!checkRateLimit(req.remoteAddress().toString()))
                return QHttpServerResponse(R"({"error":"Too Many Requests"})",
                                           QHttpServerResponse::StatusCode::TooManyRequests);
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
            if (!checkRateLimit(req.remoteAddress().toString()))
                return QHttpServerResponse(R"({"error":"Too Many Requests"})",
                                           QHttpServerResponse::StatusCode::TooManyRequests);
            if (!checkAuth(req))
                return QHttpServerResponse(R"({"error":"Unauthorized"})",
                                           QHttpServerResponse::StatusCode::Unauthorized);
            ScopedDbConnection db;
            AppConfigDao dao(db);
            auto cfg = dao.load();
            SensorDao sensorDao(db);
            auto sensors = sensorDao.loadAll();

            QJsonObject obj;
            obj["ok"]           = true;
            // "revision" is the Contract v1 field name consumed by Central Logger.
            // A value < 0 causes Central to abort saving; default in DB is 1.
            obj["revision"]     = cfg.configRevision;
            obj["station_code"] = cfg.stationCode;
            obj["station_name"] = cfg.stationName;
            obj["poll_interval"]      = cfg.pollInterval;
            obj["serial_port"]        = cfg.serialPort;
            obj["serial_baudrate"]    = cfg.serialBaudrate;
            obj["modbus_tcp_enabled"] = cfg.modbusTcpEnabled;
            obj["modbus_tcp_bind"]    = cfg.modbusTcpBind;
            obj["modbus_tcp_unit_id"] = cfg.modbusTcpUnitId;

            // Per-sensor config. data-logger (edge) is the source of truth;
            // Central consumes these read-only (e.g. `decimals` display precision).
            QJsonArray sensorArr;
            for (const auto &s : sensors) {
                QJsonObject so;
                // "sensor_id" matches the Contract v1 field name used by Central Logger.
                so["sensor_id"]   = s.id;
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
            if (!checkRateLimit(req.remoteAddress().toString()))
                return QHttpServerResponse(R"({"error":"Too Many Requests"})",
                                           QHttpServerResponse::StatusCode::TooManyRequests);
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

            // Validate writable fields before applying — a malformed value must
            // never brick the device (poll_interval=0 ⇒ busy-loop, arbitrary
            // serial_port path ⇒ injection of unknown devices).
            if (body.contains("poll_interval")) {
                const int pi = body["poll_interval"].toInt(-1);
                if (pi < 1 || pi > 3600)
                    return QHttpServerResponse(R"({"error":"poll_interval must be 1..3600 seconds"})",
                                               QHttpServerResponse::StatusCode::BadRequest);
                cfg.pollInterval = pi;
            }
            if (body.contains("serial_baudrate")) {
                static const QSet<int> kBaudrates = {
                    1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200};
                const int br = body["serial_baudrate"].toInt(-1);
                if (!kBaudrates.contains(br))
                    return QHttpServerResponse(R"({"error":"serial_baudrate is not supported"})",
                                               QHttpServerResponse::StatusCode::BadRequest);
                cfg.serialBaudrate = br;
            }

            // Apply remaining writable fields
            if (body.contains("station_name")) cfg.stationName = body["station_name"].toString();
            if (body.contains("serial_port")) {
                const QString sp = body["serial_port"].toString().trimmed();
                if (!isValidSerialPort(sp))
                    return QHttpServerResponse(R"({"error":"serial_port must be a /dev/tty* device path"})",
                                               QHttpServerResponse::StatusCode::BadRequest);
                cfg.serialPort = sp;
            }

            // station_code is a required identifier — reject the request if the caller
            // attempts to set it to an empty string.
            if (body.contains("station_code")) {
                QString sc = body["station_code"].toString().trimmed();
                if (sc.isEmpty())
                    return QHttpServerResponse(R"({"error":"station_code must not be empty"})",
                                               QHttpServerResponse::StatusCode::BadRequest);
                cfg.stationCode = sc;
            }

            cfg.configRevision++;
            dao.save(cfg);
            int rev = cfg.configRevision;

            emit configApplied(rev);

            QJsonObject resp;
            resp["ok"]       = true;
            // "revision" matches the Contract v1 field name expected by Central Logger.
            resp["revision"] = rev;
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
