#pragma once
#include <QObject>
#include <QModbusTcpServer>
#include <QModbusDataUnit>
#include <QHash>
#include <QMutex>
#include <QList>
#include <QVector>
#include <QtQmlIntegration/qqmlintegration.h>
#include "utils/QmlSingleton.h"

// Manages a QModbusTcpServer exposing sensor readings to SCADA / Central App.
class ModbusTcpServerService : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString state     READ state     NOTIFY stateChanged)
    Q_PROPERTY(bool isListening  READ isListening NOTIFY stateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString listeningEndpoint READ listeningEndpoint NOTIFY stateChanged)

public:
    static constexpr const char* STATE_STOPPED  = "stopped";
    static constexpr const char* STATE_STARTING = "starting";
    static constexpr const char* STATE_LISTENING= "listening";
    static constexpr const char* STATE_ERROR    = "error";

    explicit ModbusTcpServerService(QObject *parent);
    ~ModbusTcpServerService();

    DECLARE_QML_SINGLETON(ModbusTcpServerService)

    QString state()             const { return m_state; }
    bool    isListening()       const { return m_state == STATE_LISTENING; }
    QString lastError()         const { return m_lastError; }
    QString listeningEndpoint() const;

    Q_INVOKABLE QString primaryIp() const;

    void setSensorMap(const QList<int> &sensorIds);
    void clearSensorMap();
    void setDiDoMap(const QHash<int,int> &diMap, const QHash<int,int> &doMap);
    void updateValue(int sensorId, float value, bool isAlarm);
    void updateDi(int sensorId, bool state);
    void updateDo(int sensorId, bool state);
    void setLoggerStatus(bool polling, bool rtuConnected);

public slots:
    void start(const QString &bind, int port, int unitId);
    void stop();

signals:
    void stateChanged();
    void lastErrorChanged();

private:
    void setState(const QString &s, const QString &err = {});
    void packFloat32(float v, quint16 &hi, quint16 &lo) const;
    void packU32(quint32 v, quint16 &hi, quint16 &lo) const;
    void refreshAnyAlarmBit();

    QModbusTcpServer  *m_server = nullptr;
    // (data map is owned by m_server)
    QMutex             m_mutex;

    QString m_bind = "0.0.0.0";
    int     m_port = 5020;
    int     m_unitId = 1;
    QString m_state = STATE_STOPPED;
    QString m_lastError;

    QHash<int, int> m_sensorSlots; // sensor_id → slot index
    QHash<int, int> m_diMap;
    QHash<int, int> m_doMap;
    QList<bool>     m_diBits;
    QList<bool>     m_doBits;

    static constexpr int kHrTotal     = 1024;
    static constexpr int kSensorBase  = 10;
    static constexpr int kSensorStride= 8;
    static constexpr int kBitBlockSize= 256;

    // Register indices
    enum HrIdx { HR_VERSION=0, HR_STATUS=1, HR_TS_HI=2, HR_TS_LO=3,
                 HR_SENSOR_COUNT=4, HR_NDI=5, HR_NDO=6 };
    enum StatusFlag { FLAG_POLLING=1, FLAG_RTU=2, FLAG_ALARM=4 };
    enum SensorFlag { SF_VALID=1, SF_ALARM=2, SF_STALE=4 };
};
