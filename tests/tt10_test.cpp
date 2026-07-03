#include "utils/tt10/ReportNaming.h"
#include "tt10/Tt10ReportWriter.h"
#include "data/models/Sensor.h"
#include "data/models/SensorData.h"
#include <QCoreApplication>
#include <QDateTime>
#include <cassert>

static void testReportNaming()
{
    AppConfig cfg;
    cfg.filePrefix = QStringLiteral("HN_ABCD_NUO001_");
    cfg.fileSuffix = QStringLiteral("yyyyMMddHHmmss");
    cfg.ftpRemotePath = QStringLiteral("/");
    cfg.serverBaseFolder = QStringLiteral("NUO001");
    cfg.serverTimeFolder = QStringLiteral("yyyy/MM/dd");

    const QDateTime ts(QDate(2026, 1, 1), QTime(12, 0, 0));
    const QString fileName = ReportNaming::buildFileName(cfg, ts);
    assert(fileName == QStringLiteral("HN_ABCD_NUO001_20260101120000.txt"));

    const QString remote = ReportNaming::buildRemoteDir(cfg, ts);
    assert(remote == QStringLiteral("/NUO001/2026/01/01/"));
}

static void testDominantStatus()
{
    QList<SensorData> empty;
    assert(Tt10ReportWriter::dominantStatus(empty) == QStringLiteral("02"));

    SensorData a;
    a.status = QStringLiteral("00");
    SensorData b;
    b.status = QStringLiteral("02");
    QList<SensorData> samples{a, b};
    assert(Tt10ReportWriter::dominantStatus(samples) == QStringLiteral("02"));
}

static void testSensorSymbolForReport()
{
    Sensor s;
    s.name = QStringLiteral("Nhiệt độ");
    s.sensorSymbol = QStringLiteral("Temp");
    assert(Tt10ReportWriter::sensorSymbolForReport(s) == QStringLiteral("Temp"));

    s.sensorSymbol.clear();
    assert(Tt10ReportWriter::sensorSymbolForReport(s) == QStringLiteral("Nhiệt độ"));
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    testReportNaming();
    testDominantStatus();
    testSensorSymbolForReport();
    return 0;
}
