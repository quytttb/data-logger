#include "SensorDao.h"
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>
#include <QDebug>

SensorDao::SensorDao(QSqlDatabase db) : m_db(std::move(db)) {}

Sensor SensorDao::rowToSensor(const QSqlRecord &r) {
    Sensor s;
    s.id              = r.value("id").toInt();
    s.sensorType      = sensorTypeFromString(r.value("sensor_type").toString());
    s.name            = r.value("name").toString();
    if (r.contains(QStringLiteral("sensor_symbol")))
        s.sensorSymbol = r.value("sensor_symbol").toString();
    else
        s.sensorSymbol = r.value("parameter_code").toString();
    s.unit            = r.value("unit").toString();
    s.slaveId         = r.value("slave_id").toInt();
    s.registerAddress = r.value("register_address").toInt();
    s.registerType    = r.value("register_type").toString();
    s.dataType        = r.value("data_type").toString();
    s.dataFormat      = r.value("data_format").toString();
    s.coefficient     = r.value("coefficient").toString();
    if (!r.value("min_threshold").isNull())
        s.minThreshold = r.value("min_threshold").toDouble();
    if (!r.value("max_threshold").isNull())
        s.maxThreshold = r.value("max_threshold").toDouble();
    s.pollInterval    = r.value("poll_interval").toInt();
    s.reportIndex     = r.value("report_index").toInt();
    s.decimals        = r.value("decimals").toInt();
    s.transmitEnabled = r.contains(QStringLiteral("transmit_enabled"))
        ? r.value("transmit_enabled").toBool()
        : false;
    s.diType          = r.value("di_type").toString();
    s.active          = r.value("active").toBool();
    s.createdAt       = QDateTime::fromString(r.value("created_at").toString(), Qt::ISODate);
    return s;
}

AnalogDigitalLink SensorDao::rowToLink(const QSqlRecord &r) {
    AnalogDigitalLink l;
    l.id              = r.value("id").toInt();
    l.analogSensorId  = r.value("analog_sensor_id").toInt();
    l.digitalSensorId = r.value("digital_sensor_id").toInt();
    l.diType          = r.value("di_type").toString();
    l.triggerOnMax    = r.value("trigger_on_max").toBool();
    l.triggerOnMin    = r.value("trigger_on_min").toBool();
    l.createdAt       = QDateTime::fromString(r.value("created_at").toString(), Qt::ISODate);
    return l;
}

QList<Sensor> SensorDao::loadAll(bool activeOnly) {
    QSqlQuery q(m_db);
    if (activeOnly)
        q.exec("SELECT * FROM sensor WHERE active=1 ORDER BY id");
    else
        q.exec("SELECT * FROM sensor ORDER BY id");

    QList<Sensor> result;
    while (q.next())
        result.append(rowToSensor(q.record()));
    return result;
}

Sensor SensorDao::loadById(int id) {
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM sensor WHERE id=:id");
    q.bindValue(":id", id);
    q.exec();
    if (q.next()) return rowToSensor(q.record());
    return {};
}

bool SensorDao::save(Sensor &s) {
    QSqlQuery q(m_db);
    if (s.id == 0) {
        q.prepare(R"(INSERT INTO sensor
            (sensor_type, name, sensor_symbol, unit, slave_id, register_address,
             register_type, data_type, data_format, coefficient,
             min_threshold, max_threshold, poll_interval, report_index,
             decimals, transmit_enabled, di_type, active)
            VALUES (:st, :nm, :sym, :un, :sid, :ra,
                    :rt, :dt, :df, :co,
                    :mn, :mx, :pi, :ri,
                    :dec, :tx, :dit, :act))");
    } else {
        q.prepare(R"(UPDATE sensor SET
            sensor_type=:st, name=:nm, sensor_symbol=:sym, unit=:un, slave_id=:sid,
            register_address=:ra, register_type=:rt, data_type=:dt,
            data_format=:df, coefficient=:co, min_threshold=:mn,
            max_threshold=:mx, poll_interval=:pi, report_index=:ri,
            decimals=:dec, transmit_enabled=:tx, di_type=:dit, active=:act WHERE id=:id)");
        q.bindValue(":id", s.id);
    }

    q.bindValue(":st",  sensorTypeToString(s.sensorType));
    q.bindValue(":nm",  s.name);
    q.bindValue(":sym", s.sensorSymbol);
    q.bindValue(":un",  s.unit);
    q.bindValue(":sid", s.slaveId);
    q.bindValue(":ra",  s.registerAddress);
    q.bindValue(":rt",  s.registerType);
    q.bindValue(":dt",  s.dataType);
    q.bindValue(":df",  s.dataFormat);
    q.bindValue(":co",  s.coefficient);
    q.bindValue(":mn",  s.minThreshold.has_value() ? QVariant(*s.minThreshold) : QVariant());
    q.bindValue(":mx",  s.maxThreshold.has_value() ? QVariant(*s.maxThreshold) : QVariant());
    q.bindValue(":pi",  s.pollInterval);
    q.bindValue(":ri",  s.reportIndex);
    q.bindValue(":dec", s.decimals);
    q.bindValue(":tx",  s.transmitEnabled ? 1 : 0);
    q.bindValue(":dit", s.diType.isEmpty() ? QVariant() : QVariant(s.diType));
    q.bindValue(":act", s.active ? 1 : 0);

    if (!q.exec()) {
        qWarning() << "SensorDao::save error:" << q.lastError().text();
        return false;
    }
    if (s.id == 0)
        s.id = q.lastInsertId().toInt();
    return true;
}

bool SensorDao::remove(int id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM sensor WHERE id=:id");
    q.bindValue(":id", id);
    return q.exec();
}

QList<AnalogDigitalLink> SensorDao::loadAllLinks() {
    QSqlQuery q(m_db);
    q.exec("SELECT * FROM analog_digital_link ORDER BY id");
    QList<AnalogDigitalLink> result;
    while (q.next())
        result.append(rowToLink(q.record()));
    return result;
}

bool SensorDao::saveLink(AnalogDigitalLink &l) {
    QSqlQuery q(m_db);
    if (l.id == 0) {
        q.prepare(R"(INSERT INTO analog_digital_link
            (analog_sensor_id, digital_sensor_id, di_type, trigger_on_max, trigger_on_min)
            VALUES (:a, :d, :dt, :tm, :tmin))");
    } else {
        q.prepare(R"(UPDATE analog_digital_link SET
            analog_sensor_id=:a, digital_sensor_id=:d,
            di_type=:dt, trigger_on_max=:tm, trigger_on_min=:tmin
            WHERE id=:id)");
        q.bindValue(":id", l.id);
    }
    q.bindValue(":a",    l.analogSensorId);
    q.bindValue(":d",    l.digitalSensorId);
    q.bindValue(":dt",   l.diType.isEmpty() ? QVariant() : QVariant(l.diType));
    q.bindValue(":tm",   l.triggerOnMax ? 1 : 0);
    q.bindValue(":tmin", l.triggerOnMin ? 1 : 0);
    if (!q.exec()) return false;
    if (l.id == 0) l.id = q.lastInsertId().toInt();
    return true;
}

bool SensorDao::removeLink(int id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM analog_digital_link WHERE id=:id");
    q.bindValue(":id", id);
    return q.exec();
}

QList<AnalogDigitalLink> SensorDao::linksForAnalog(int analogSensorId) {
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM analog_digital_link WHERE analog_sensor_id=:a ORDER BY id");
    q.bindValue(":a", analogSensorId);
    q.exec();
    QList<AnalogDigitalLink> result;
    while (q.next())
        result.append(rowToLink(q.record()));
    return result;
}

bool SensorDao::updateTransmission(int id, const QString &sensorSymbol, bool transmitEnabled)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sensor SET sensor_symbol=:sym, transmit_enabled=:tx WHERE id=:id");
    q.bindValue(":sym", sensorSymbol);
    q.bindValue(":tx", transmitEnabled ? 1 : 0);
    q.bindValue(":id", id);
    return q.exec();
}

bool SensorDao::setAllTransmitEnabled(bool enabled)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE sensor SET transmit_enabled=:tx WHERE active=1");
    q.bindValue(":tx", enabled ? 1 : 0);
    return q.exec();
}

bool SensorDao::clearTransmission(const QList<int> &ids)
{
    if (ids.isEmpty())
        return true;
    QSqlQuery q(m_db);
    QStringList placeholders;
    for (int i = 0; i < ids.size(); ++i)
        placeholders << QStringLiteral(":id%1").arg(i);
    q.prepare(QStringLiteral("UPDATE sensor SET transmit_enabled=0 WHERE id IN (%1)")
                  .arg(placeholders.join(QLatin1Char(','))));
    for (int i = 0; i < ids.size(); ++i)
        q.bindValue(QStringLiteral(":id%1").arg(i), ids.at(i));
    return q.exec();
}
