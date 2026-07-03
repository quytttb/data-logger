#include "Tt10ReportWriter.h"
#include "data/repositories/SensorDataDao.h"
#include <QFile>
#include <QTextStream>
#include <QStringConverter>
#include <optional>

namespace {

int statusPriority(const QString &status)
{
    if (status == QStringLiteral("02")) return 4;
    if (status == QStringLiteral("03")) return 3;
    if (status == QStringLiteral("01")) return 2;
    if (status == QStringLiteral("00")) return 1;
    return 0;
}

std::optional<double> averageValue(const QList<SensorData> &samples)
{
    double sum = 0.0;
    int count = 0;
    for (const auto &d : samples) {
        if (!d.value.has_value())
            continue;
        sum += *d.value;
        ++count;
    }
    if (count == 0)
        return std::nullopt;
    return sum / static_cast<double>(count);
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

        const auto samples = dataDao.query(sensor.id, from, to, 10000);
        const auto avg = averageValue(samples);
        const QString valueStr = avg.has_value()
            ? QString::number(*avg, 'f', sensor.decimals)
            : QStringLiteral("---");
        const QString status = dominantStatus(samples);

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
