#include "Formula.h"
#include <QJsonDocument>
#include <QJsonObject>

namespace Formula {
double applyFormula(double raw, const QString &coeffJson) {
    if (coeffJson.isEmpty() || coeffJson == "{}") return raw;
    QJsonDocument doc = QJsonDocument::fromJson(coeffJson.toUtf8());
    if (!doc.isObject()) return raw;
    QJsonObject obj = doc.object();
    double a = obj.value("a").toDouble(1.0);
    double b = obj.value("b").toDouble(0.0);
    return a * raw + b;
}
}
