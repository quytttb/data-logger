#include "ReportController.h"
#include "utils/AppPaths.h"
#include "data/db/Database.h"
#include "data/repositories/SensorDao.h"
#include "data/repositories/SensorDataDao.h"
#include "data/repositories/ReportLogDao.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDebug>

ReportController::ReportController(QObject *parent) : QObject(parent) {}

void ReportController::generateReport(const QDateTime &from, const QDateTime &to) {
    auto db = Database::openConnection();
    SensorDao sDao(db);
    SensorDataDao sdDao(db);
    ReportLogDao logDao(db);

    auto sensors = sDao.loadAll(true);

    // Sort by report_index
    std::sort(sensors.begin(), sensors.end(),
              [](const Sensor &a, const Sensor &b){ return a.reportIndex < b.reportIndex; });

    // Filename: YYYYMMDD_HHmmss.txt
    QString fname = from.toString("yyyyMMdd_HHmmss") + ".txt";
    QDir().mkpath(AppPaths::dataDir());
    QString path = AppPaths::dataDir() + "/" + fname;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit messageSent("Error", "Cannot write report file: " + path);
        db.close();
        return;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    // Header
    out << "Thoi gian: " << from.toString("dd/MM/yyyy HH:mm:ss")
        << " - " << to.toString("dd/MM/yyyy HH:mm:ss") << "\n";
    out << "STT";
    for (const auto &s : sensors)
        out << "\t" << s.name + " (" + s.unit + ")";
    out << "\n";

    // Gather data rows (one per minute, averaged)
    QDateTime cursor = from;
    int row = 1;
    while (cursor <= to) {
        QDateTime next = cursor.addSecs(60);
        out << row++;
        for (const auto &s : sensors) {
            auto data = sdDao.query(s.id, cursor, next, 60);
            if (data.isEmpty()) { out << "\t---"; continue; }
            double sum = 0; int cnt = 0;
            for (const auto &d : data)
                if (d.value.has_value()) { sum += *d.value; ++cnt; }
            if (cnt > 0) out << "\t" << QString::number(sum/cnt, 'f', 4);
            else          out << "\t---";
        }
        out << "\n";
        cursor = next;
    }
    file.close();

    // Log to report_log table
    ReportLog log;
    log.filePath = path;
    logDao.insert(log);
    db.close();

    emit reportGenerated(path);
    emit messageSent("Success", "Report saved: " + fname);
}
