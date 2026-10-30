#include "CalibrationMath.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>

#include <algorithm>
#include <cmath>
#include <limits>

namespace CalibrationMath {

namespace {

// Dung sai tương đối cho "raw phải khác nhau". Không dùng so sánh tuyệt đối
// vì cảm biến có thể trả giá trị rất lớn (dòng điện/áp) hoặc rất nhỏ.
bool rawValuesVary(const QList<Point> &points)
{
    double minRaw = points.first().raw;
    double maxRaw = points.first().raw;
    for (const Point &point : points) {
        minRaw = std::min(minRaw, point.raw);
        maxRaw = std::max(maxRaw, point.raw);
    }
    const long double scale = std::max(std::abs(static_cast<long double>(minRaw)),
                                       std::abs(static_cast<long double>(maxRaw)));
    const long double spread = static_cast<long double>(maxRaw) - minRaw;
    return spread > 4.0L * std::numeric_limits<double>::epsilon() * scale;
}

FitResult failure(const QString &message)
{
    FitResult result;
    result.ok = false;
    result.error = message;
    return result;
}

} // namespace

FitResult fit(const QList<Point> &points)
{
    if (points.size() < 2)
        return failure(QStringLiteral("At least 2 calibration points are required."));

    for (int i = 0; i < points.size(); ++i) {
        const Point &point = points.at(i);
        if (!std::isfinite(point.raw) || !std::isfinite(point.reference)) {
            return failure(QStringLiteral("Point %1: values must be finite numbers.")
                               .arg(i + 1));
        }
    }

    if (!rawValuesVary(points))
        return failure(QStringLiteral(
            "Raw values must differ between calibration points."));

    // Dùng long double + dời gốc theo điểm đầu để giảm sai số triệt tiêu khi
    // raw lớn (vd 4000..20000) và tránh tràn trung gian.
    const long double x0 = static_cast<long double>(points.first().raw);
    const long double n = static_cast<long double>(points.size());
    long double sumX = 0.0L;
    long double sumY = 0.0L;
    for (const Point &point : points) {
        sumX += static_cast<long double>(point.raw) - x0;
        sumY += static_cast<long double>(point.reference);
    }
    const long double meanX = sumX / n;
    const long double meanY = sumY / n;

    long double sxx = 0.0L;
    long double sxy = 0.0L;
    long double syy = 0.0L;
    for (const Point &point : points) {
        const long double dx = static_cast<long double>(point.raw) - x0 - meanX;
        const long double dy = static_cast<long double>(point.reference) - meanY;
        sxx += dx * dx;
        sxy += dx * dy;
        syy += dy * dy;
    }

    if (!(sxx > 0.0L) || !std::isfinite(sxx) || !std::isfinite(sxy)
        || !std::isfinite(syy))
        return failure(QStringLiteral(
            "Calibration values are too close or out of range."));

    const long double slope = sxy / sxx;
    const long double intercept = meanY - slope * (x0 + meanX);

    FitResult result;
    result.a = static_cast<double>(slope);
    result.b = static_cast<double>(intercept);
    if (!std::isfinite(result.a) || !std::isfinite(result.b))
        return failure(QStringLiteral("Calibration result is out of range."));

    double maxResidual = 0.0;
    long double sumSquaredResiduals = 0.0L;
    result.residuals.reserve(points.size());
    for (const Point &point : points) {
        const double predicted = result.a * point.raw + result.b;
        if (!std::isfinite(predicted))
            return failure(QStringLiteral("Calibration result is out of range."));
        const double residual = point.reference - predicted;
        if (!std::isfinite(residual))
            return failure(QStringLiteral("Calibration result is out of range."));
        result.residuals.append(residual);
        maxResidual = std::max(maxResidual, std::abs(residual));
        sumSquaredResiduals += static_cast<long double>(residual) * residual;
    }
    result.maxResidual = maxResidual;

    // Dùng chính các residual của hệ số double mà runtime sẽ áp dụng. Nhờ vậy
    // R² không che giấu sai số do làm tròn a/b. Syy = 0 thì R² không xác định.
    if (!std::isfinite(sumSquaredResiduals))
        return failure(QStringLiteral("Calibration result is out of range."));
    if (syy > 0.0L) {
        const double r2 = static_cast<double>(1.0L - sumSquaredResiduals / syy);
        if (!std::isfinite(r2))
            return failure(QStringLiteral("Calibration result is out of range."));
        result.r2 = r2;
    }

    result.ok = true;
    return result;
}

QString coefficientJson(double a, double b)
{
    QJsonObject obj;
    obj.insert(QStringLiteral("a"), a);
    obj.insert(QStringLiteral("b"), b);
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

bool parseCoefficient(const QString &json, double *a, double *b)
{
    if (!a || !b)
        return false;

    const QString trimmed = json.trimmed();
    if (trimmed.isEmpty())
        return false;

    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(trimmed.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return false;

    const QJsonObject obj = doc.object();
    const QJsonValue valueA = obj.value(QStringLiteral("a"));
    const QJsonValue valueB = obj.value(QStringLiteral("b"));
    if (!valueA.isDouble() || !valueB.isDouble())
        return false;

    const double parsedA = valueA.toDouble();
    const double parsedB = valueB.toDouble();
    if (!std::isfinite(parsedA) || !std::isfinite(parsedB))
        return false;

    *a = parsedA;
    *b = parsedB;
    return true;
}

} // namespace CalibrationMath
