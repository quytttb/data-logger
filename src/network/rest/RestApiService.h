#pragma once
#include <QObject>
#include <QHttpServer>
#include <QHttpServerRequest>
#include <QHttpServerResponse>
#include <QTcpServer>
#include <QVariantMap>
#include <QMutex>
#include <functional>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/qml/QmlSingleton.h"
#include "utils/system/AppDefaults.h"

// Embeds a QHttpServer to serve the REST API on the LAN.
class RestApiService : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString state     READ state     NOTIFY stateChanged)
    Q_PROPERTY(bool isListening  READ isListening NOTIFY stateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString listeningEndpoint READ listeningEndpoint NOTIFY stateChanged)

public:
    static inline const QString STATE_STOPPED   = QStringLiteral("stopped");
    static inline const QString STATE_LISTENING = QStringLiteral("listening");
    static inline const QString STATE_ERROR     = QStringLiteral("error");

    explicit RestApiService(QObject *parent);

    DECLARE_QML_SINGLETON(RestApiService)

    QString state()             const { return m_state; }
    bool    isListening()       const { return m_state == STATE_LISTENING; }
    QString lastError()         const { return m_lastError; }
    QString listeningEndpoint() const;

    Q_INVOKABLE QString primaryIp() const;

    void setToken(const QString &token);
    void setReadingsProvider(std::function<QVariantMap()> provider);
    // Health snapshot (uptime, modbus_connected, ...) — gọi từ main.cpp.
    void setHealthProvider(std::function<QVariantMap()> provider);

public slots:
    void start(const QString &bind, int port, const QString &token);
    void stop();

signals:
    void stateChanged();
    void lastErrorChanged();
    void configApplied(int revision);

private:
    bool checkAuth(const QHttpServerRequest &req) const;
    // Token-bucket đơn giản per IP: quá kRateLimitPerSec req/s → 429.
    bool checkRateLimit(const QString &ip);
    void setupRoutes();
    void setState(const QString &s, const QString &err = {});

    QHttpServer  *m_server    = nullptr;
    QTcpServer   *m_tcpServer = nullptr;

    static inline const QString kDefaultBind = AppDefaults::bindAnyIPv4;
    static constexpr int        kDefaultPort = AppDefaults::restApiPort;

    QString m_bind  = kDefaultBind;
    int     m_port  = kDefaultPort;
    QString m_token;
    QString m_state = STATE_STOPPED;
    QString m_lastError;
    mutable QMutex m_mutex;

    std::function<QVariantMap()> m_readingsProvider;
    std::function<QVariantMap()> m_healthProvider;

    // Rate-limit state: ip → (windowStartMs, count). Guarded by m_mutex.
    QHash<QString, QPair<qint64, int>> m_rateBuckets;
    static constexpr int kRateLimitPerSec = 10;
};
