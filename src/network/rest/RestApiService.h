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
#include "utils/QmlSingleton.h"

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
    static constexpr const char* STATE_STOPPED  = "stopped";
    static constexpr const char* STATE_LISTENING= "listening";
    static constexpr const char* STATE_ERROR    = "error";

    explicit RestApiService(QObject *parent);

    DECLARE_QML_SINGLETON(RestApiService)

    QString state()             const { return m_state; }
    bool    isListening()       const { return m_state == STATE_LISTENING; }
    QString lastError()         const { return m_lastError; }
    QString listeningEndpoint() const;

    Q_INVOKABLE QString primaryIp() const;

    void setToken(const QString &token);
    void setReadingsProvider(std::function<QVariantMap()> provider);

public slots:
    void start(const QString &bind, int port, const QString &token);
    void stop();

signals:
    void stateChanged();
    void lastErrorChanged();
    void configApplied(int revision);

private:
    bool checkAuth(const QHttpServerRequest &req) const;
    void setupRoutes();
    void setState(const QString &s, const QString &err = {});

    QHttpServer  *m_server    = nullptr;
    QTcpServer   *m_tcpServer = nullptr;

    QString m_bind  = "0.0.0.0";
    int     m_port  = 8080;
    QString m_token;
    QString m_state = STATE_STOPPED;
    QString m_lastError;
    mutable QMutex m_mutex;

    std::function<QVariantMap()> m_readingsProvider;
};
