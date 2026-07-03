#pragma once
#include "data/models/Sensor.h"
#include "data/models/SensorData.h"
#include <QDateTime>
#include <QString>
#include <QList>

class SensorDataDao;

namespace Tt10ReportWriter {

bool write(const QString &path,
           const QList<Sensor> &sensors,
           SensorDataDao &dataDao,
           const QDateTime &from,
           const QDateTime &to);

QString dominantStatus(const QList<SensorData> &samples);
QString sensorSymbolForReport(const Sensor &sensor);

} // namespace Tt10ReportWriter
