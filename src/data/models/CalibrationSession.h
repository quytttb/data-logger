#pragma once
#include <QDateTime>
#include <QList>
#include <QString>
#include <optional>

struct CalibrationPoint {
    int id = 0;
    double rawValue = 0.0;
    double referenceValue = 0.0;
    QString note = QStringLiteral("");
};

// Một phiên hiệu chuẩn tuyến tính 2..N điểm. Điểm được lưu riêng để giữ
// lịch sử; sensor.coefficient vẫn là nguồn runtime (Formula::applyFormula).
struct CalibrationSession {
    int id = 0;
    int sensorId = 0;
    QString method = QStringLiteral("linear");
    int pointCount = 0;
    double a = 1.0;
    double b = 0.0;
    std::optional<double> r2;
    std::optional<double> maxResidual;
    QString note = QStringLiteral("");
    int createdBy = 0;                   // 0 = không gắn tài khoản
    QString createdByUsername = QStringLiteral("");  // snapshot
    QDateTime createdAt;
    QList<CalibrationPoint> points;      // chỉ dùng khi save/load chi tiết
};
