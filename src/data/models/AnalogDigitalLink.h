#pragma once
#include <QString>
#include <QDateTime>

struct AnalogDigitalLink {
    int id = 0;
    int analogSensorId = 0;
    int digitalSensorId = 0;
    QString diType;
    bool triggerOnMax = true;
    bool triggerOnMin = true;
    QDateTime createdAt;
};
