#pragma once
#include "data/models/Sensor.h"
#include "data/models/AnalogDigitalLink.h"
#include <QSqlDatabase>
#include <QList>

class SensorDao {
public:
    explicit SensorDao(QSqlDatabase db);

    QList<Sensor> loadAll(bool activeOnly = false);
    Sensor loadById(int id);
    bool save(Sensor &sensor);   // sets sensor.id on insert
    bool remove(int id);

    QList<AnalogDigitalLink> loadAllLinks();
    bool saveLink(AnalogDigitalLink &link);
    bool removeLink(int id);
    QList<AnalogDigitalLink> linksForAnalog(int analogSensorId);

    bool updateTransmission(int id, const QString &sensorSymbol, bool transmitEnabled);
    bool setAllTransmitEnabled(bool enabled);
    bool clearTransmission(const QList<int> &ids);

private:
    QSqlDatabase m_db;
    Sensor rowToSensor(const class QSqlRecord &r);
    AnalogDigitalLink rowToLink(const class QSqlRecord &r);
};
