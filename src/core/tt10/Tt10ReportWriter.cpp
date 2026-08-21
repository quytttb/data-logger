#include "Tt10ReportWriter.h"
#include "data/repositories/SensorDataDao.h"
#include <QFile>
#include <QTextStream>
#include <QStringConverter>

namespace {

int statusPriority(const QString &status)
{
    if (status == QStringLiteral("02")) return 4;
    if (status == QStringLiteral("03")) return 3;
    if (status == QStringLiteral("01")) return 2;
    if (status == QStringLiteral("00")) return 1;
    return 0;
}

} // namespace

namespace Tt10ReportWriter {

QString sensorSymbolForReport(const Sensor &sensor)
{
    if (!sensor.sensorSymbol.trimmed().isEmpty())
        return sensor.sensorSymbol.trimmed();
    return sensor.name.trimmed();
}

QString dominantStatus(const QList<SensorData> &samples)
{
    QString best = QStringLiteral("00");
    int bestPri = 0;
    for (const auto &d : samples) {
        if (d.status.isEmpty())
            continue;
        const int pri = statusPriority(d.status);
        if (pri > bestPri) {
            bestPri = pri;
            best = d.status;
        }
    }
    if (bestPri == 0 && samples.isEmpty())
        return QStringLiteral("02");
    return best;
}

QString dominantStatusFromDistinct(const QStringList &statuses)
{
    if (statuses.isEmpty())
        return QStringLiteral("02");
    QString best = QStringLiteral("00");
    int bestPri = 0;
    for (const auto &s : statuses) {
        if (s.isEmpty())
            continue;
        const int pri = statusPriority(s);
        if (pri > bestPri) {
            bestPri = pri;
            best = s;
        }
    }
    if (bestPri == 0)
        return QStringLiteral("00");
    return best;
}

bool write(const QString &path,
           const QList<Sensor> &sensors,
           SensorDataDao &dataDao,
           const QDateTime &from,
           const QDateTime &to)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    const QString timeStamp = to.toString(QStringLiteral("yyyyMMddHHmmss"));
    QStringList fields;

    for (const auto &sensor : sensors) {
        if (sensor.sensorType != SensorType::Analog || !sensor.transmitEnabled)
            continue;

        // H-6 fix: aggregate in SQL (AVG/COUNT) instead of pulling at most
        // 10000 rows and averaging them — a window with >10000 samples used to
        // silently produce the wrong average.
        const auto agg = dataDao.aggregateWindow(sensor.id, from, to);
        const QString valueStr = agg.average.has_value()
            ? QString::number(*agg.average, 'f', sensor.decimals)
            : QStringLiteral("---");
        const QString status = dominantStatusFromDistinct(agg.distinctStatuses);

        fields << sensorSymbolForReport(sensor)
               << valueStr
               << sensor.unit
               << timeStamp
               << status;
    }

    out << fields.join(QLatin1Char('\t')) << QLatin1Char('\n');
    file.close();
    return true;
}

} // namespace Tt10ReportWriter
