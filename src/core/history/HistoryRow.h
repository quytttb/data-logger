#pragma once
#include <QString>
#include <QDateTime>

struct HistoryRow {
    QDateTime recordedAt;
    QString   sensorName;
    QString   unit;
    QString   valueText;
    QString   rawValueText;
    QString   status;
    bool      isAlarm = false;
};
