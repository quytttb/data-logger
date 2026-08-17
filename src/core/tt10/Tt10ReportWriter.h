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
/// Same priority rule as dominantStatus(), but over the window's DISTINCT
/// statuses (no per-sample scan). Returns "02" when the set is empty.
QString dominantStatusFromDistinct(const QStringList &statuses);
QString sensorSymbolForReport(const Sensor &sensor);

} // namespace Tt10ReportWriter
