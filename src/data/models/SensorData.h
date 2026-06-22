#pragma once
#include <QString>
#include <QDateTime>
#include <optional>

struct SensorData {
    int id = 0;
    int sensorId = 0;
    std::optional<double> rawValue;
    std::optional<double> value;
    QString status;
    bool isAlarm = false;
    QString alarmType;
    QDateTime recordedAt;
};
