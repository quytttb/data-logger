#pragma once
#include <QString>
#include <QDateTime>
#include <optional>

enum class SensorType { Analog, DI, DO };

inline SensorType sensorTypeFromString(const QString &s) {
    if (s == "DI") return SensorType::DI;
    if (s == "DO") return SensorType::DO;
    return SensorType::Analog;
}

inline QString sensorTypeToString(SensorType t) {
    switch (t) {
    case SensorType::DI: return "DI";
    case SensorType::DO: return "DO";
    default:             return "ANALOG";
    }
}

struct Sensor {
    int id = 0;
    SensorType sensorType = SensorType::Analog;
    QString name;
    QString unit;
    int slaveId = 1;
    int registerAddress = 0;
    QString registerType = "holding";  // "holding" | "input" | "coil" | "discrete_input"
    QString dataType = "int16";        // int16 | uint16 | int32 | uint32 | float32
    QString dataFormat = "AB";         // AB | BA | ABCD | CDAB | BADC | DCBA
    QString coefficient = "{}";        // JSON: {"a": 1.0, "b": 0.0}
    std::optional<double> minThreshold;
    std::optional<double> maxThreshold;
    int pollInterval = 3;              // seconds
    int reportIndex = 0;
    QString diType;
    bool active = true;
    QDateTime createdAt;
};
