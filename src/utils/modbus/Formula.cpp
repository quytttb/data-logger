#include "Formula.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <cmath>

namespace Formula {
double applyFormula(double raw, const QString &coeffJson) {
    if (coeffJson.isEmpty() || coeffJson == "{}") {
        if (!std::isfinite(raw))
            return 0.0;
        return raw;
    }
    QJsonDocument doc = QJsonDocument::fromJson(coeffJson.toUtf8());
    if (!doc.isObject()) {
        if (!std::isfinite(raw))
            return 0.0;
        return raw;
    }
    QJsonObject obj = doc.object();
    double a = obj.value("a").toDouble(1.0);
    double b = obj.value("b").toDouble(0.0);
    if (!std::isfinite(a) || !std::isfinite(b))
        return std::isfinite(raw) ? raw : 0.0;
    const double v = a * raw + b;
    if (!std::isfinite(v))
        return 0.0;
    return v;
}
}
