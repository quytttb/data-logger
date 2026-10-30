#include "CalibrationController.h"

#include "AuditTrail.h"
#include "AuthService.h"
#include "SensorListModel.h"
#include "data/db/Database.h"
#include "data/db/TimeCodec.h"
#include "data/models/Sensor.h"
#include "data/repositories/AppConfigDao.h"
#include "data/repositories/CalibrationDao.h"
#include "data/repositories/SensorDao.h"
#include "utils/calc/CalibrationMath.h"

#include <QJsonObject>
#include <QVariantMap>
#include <QtDebug>
#include <cmath>

IMPLEMENT_QML_SINGLETON(CalibrationController)

namespace {

// Nhận number hoặc chuỗi số; chuỗi rỗng coi như "ô trống".
bool parseNumber(const QVariant &value, double *out, bool *empty)
{
    *empty = false;
    switch (value.typeId()) {
    case QMetaType::Double:
    case QMetaType::Float:
    case QMetaType::Int:
    case QMetaType::LongLong:
    case QMetaType::UInt:
    case QMetaType::ULongLong:
        *out = value.toDouble();
        return std::isfinite(*out);
    default:
        break;
    }

    QString text = value.toString().trimmed();
    if (text.isEmpty()) {
        *empty = true;
        return false;
    }
    text.replace(QLatin1Char(','), QLatin1Char('.'));
    bool ok = false;
    *out = text.toDouble(&ok);
    return ok && std::isfinite(*out);
}

// Chuyển QVariantList từ QML thành điểm. Bỏ qua dòng hoàn toàn trống để người
// dùng có thể để sẵn dòng mới; dòng thiếu một nửa là lỗi rõ ràng.
bool collectPoints(const QVariantList &input, QList<CalibrationMath::Point> *out,
                   QString *error)
{
    out->clear();
    for (int i = 0; i < input.size(); ++i) {
        const QVariantMap row = input.at(i).toMap();
        bool rawEmpty = false;
        bool refEmpty = false;
        double raw = 0.0;
        double reference = 0.0;
        const bool rawOk = parseNumber(row.value(QStringLiteral("raw")), &raw, &rawEmpty);
        const bool refOk = parseNumber(row.value(QStringLiteral("reference")), &reference,
                                       &refEmpty);

        if (rawEmpty && refEmpty)
            continue;
        if (!rawOk || !refOk) {
            *error = QStringLiteral("Point %1: enter both raw and reference values.")
                         .arg(i + 1);
            return false;
        }
        out->append({raw, reference});
    }

    if (out->size() < 2) {
        *error = QStringLiteral("At least 2 calibration points are required.");
        return false;
    }
    return true;
}

QVariantMap failure(const QString &error, const QString &title = QString())
{
    QVariantMap out;
    out.insert(QStringLiteral("ok"), false);
    out.insert(QStringLiteral("error"), error);
    if (!title.isEmpty())
        out.insert(QStringLiteral("title"), title);
    return out;
}

QVariantMap sessionToMap(const CalibrationSession &session)
{
    QVariantMap map;
    map.insert(QStringLiteral("id"), session.id);
    map.insert(QStringLiteral("sensorId"), session.sensorId);
    map.insert(QStringLiteral("pointCount"), session.pointCount);
    map.insert(QStringLiteral("a"), session.a);
    map.insert(QStringLiteral("b"), session.b);
    map.insert(QStringLiteral("r2"), session.r2.has_value()
                  ? QVariant(*session.r2) : QVariant());
    map.insert(QStringLiteral("maxResidual"), session.maxResidual.has_value()
                  ? QVariant(*session.maxResidual) : QVariant());
    map.insert(QStringLiteral("note"), session.note);
    map.insert(QStringLiteral("createdBy"), session.createdBy);
    map.insert(QStringLiteral("createdByUsername"), session.createdByUsername);
    map.insert(QStringLiteral("createdAt"), session.createdAt.isValid()
                  ? TimeCodec::toDb(session.createdAt) : QString());
    return map;
}

} // namespace

CalibrationController::CalibrationController(QObject *parent) : QObject(parent) {}

QVariantMap CalibrationController::fit(const QVariantList &points) const
{
    QList<CalibrationMath::Point> parsed;
    QString error;
    if (!collectPoints(points, &parsed, &error))
        return failure(error);

    const CalibrationMath::FitResult result = CalibrationMath::fit(parsed);
    if (!result.ok)
        return failure(result.error);

    QVariantList residuals;
    for (double residual : result.residuals)
        residuals.append(residual);

    QVariantMap out;
    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("pointCount"), parsed.size());
    out.insert(QStringLiteral("a"), result.a);
    out.insert(QStringLiteral("b"), result.b);
    out.insert(QStringLiteral("r2"), result.r2.has_value()
                  ? QVariant(*result.r2) : QVariant());
    out.insert(QStringLiteral("maxResidual"), result.maxResidual.has_value()
                  ? QVariant(*result.maxResidual) : QVariant());
    out.insert(QStringLiteral("residuals"), residuals);
    return out;
}

QVariantMap CalibrationController::current(int sensorId) const
{
    if (!AuthService::authorize(Permission::ViewData))
        return failure(QStringLiteral("Permission denied."));

    ScopedDbConnection db;
    if (!db.get().isOpen())
        return failure(QStringLiteral("Database is not available."));

    SensorDao sensorDao(db);
    const Sensor sensor = sensorDao.loadById(sensorId);
    if (sensor.id == 0)
        return failure(QStringLiteral("Sensor not found."));

    double a = 1.0;
    double b = 0.0;
    const bool hasCoefficient = CalibrationMath::parseCoefficient(sensor.coefficient, &a, &b);

    CalibrationDao calibrationDao(db);
    const std::optional<CalibrationSession> latest =
        calibrationDao.latestForSensor(sensorId);

    QVariantMap out;
    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("a"), a);
    out.insert(QStringLiteral("b"), b);
    out.insert(QStringLiteral("hasCoefficient"), hasCoefficient);
    out.insert(QStringLiteral("coefficient"), sensor.coefficient);
    out.insert(QStringLiteral("hasPoints"), latest.has_value());
    out.insert(QStringLiteral("lastSession"),
               latest.has_value() ? sessionToMap(*latest) : QVariant());
    return out;
}

QVariantList CalibrationController::history(int sensorId) const
{
    QVariantList out;
    if (!AuthService::authorize(Permission::ViewData))
        return out;

    ScopedDbConnection db;
    if (!db.get().isOpen())
        return out;

    CalibrationDao dao(db);
    for (const CalibrationSession &session : dao.recentSessions(sensorId, 20))
        out.append(sessionToMap(session));
    return out;
}

QVariantList CalibrationController::sessionPoints(int sessionId) const
{
    QVariantList out;
    if (!AuthService::authorize(Permission::ViewData))
        return out;

    ScopedDbConnection db;
    if (!db.get().isOpen())
        return out;

    CalibrationDao dao(db);
    for (const CalibrationPoint &point : dao.pointsForSession(sessionId)) {
        out.append(QVariantMap{
            {QStringLiteral("id"), point.id},
            {QStringLiteral("raw"), point.rawValue},
            {QStringLiteral("reference"), point.referenceValue},
            {QStringLiteral("note"), point.note},
        });
    }
    return out;
}

QVariantMap CalibrationController::apply(int sensorId, const QVariantList &points,
                                         const QString &note)
{
    const AuditTrail::Actor actor = AuditTrail::localActor();

    if (!AuthService::authorize(Permission::Calibrate)) {
        AuditLogEntry denied = AuditTrail::entry(
            actor, QStringLiteral("calibration.apply"), QStringLiteral("sensor"),
            QString::number(sensorId), AuditResult::Denied,
            AuditTrail::snapshot({{QStringLiteral("reason"),
                                   QStringLiteral("missing_permission")}}));
        AuditTrail::appendStandalone(denied);
        emit messageSent(QStringLiteral("Permission denied"),
                         QStringLiteral("Only operators and administrators can "
                                        "calibrate sensors."));
        return failure(QStringLiteral("Permission denied."));
    }

    QList<CalibrationMath::Point> parsed;
    QString parseError;
    if (!collectPoints(points, &parsed, &parseError))
        return failure(parseError);

    const CalibrationMath::FitResult fitResult = CalibrationMath::fit(parsed);
    if (!fitResult.ok)
        return failure(fitResult.error);

    const QString trimmedNote = note.trimmed();
    bool ok = false;
    QString failureText = QStringLiteral("Could not save the calibration.");
    int sessionId = 0;

    // Chuyển sang model DB một lần, trước transaction (không giữ write lock
    // trong lúc dựng dữ liệu).
    QList<CalibrationPoint> dbPoints;
    dbPoints.reserve(parsed.size());
    for (const CalibrationMath::Point &point : parsed) {
        CalibrationPoint dbPoint;
        dbPoint.rawValue = point.raw;
        dbPoint.referenceValue = point.reference;
        dbPoints.append(dbPoint);
    }

    {
        ScopedDbConnection db;
        SensorDao sensorDao(db);
        CalibrationDao calibrationDao(db);
        AppConfigDao configDao(db);
        QSqlDatabase &sql = db.get();

        // Đọc cảm biến sau khi bắt đầu transaction để không ghi đè cấu hình
        // đã đổi đồng thời bằng snapshot cũ.
        const bool began = sql.transaction();
        Sensor sensor = began ? sensorDao.loadById(sensorId) : Sensor{};
        if (!began) {
            failureText = QStringLiteral("Could not start the calibration transaction.");
        } else if (sensor.id == 0) {
            failureText = QStringLiteral("Sensor not found.");
        } else if (sensor.sensorType != SensorType::Analog) {
            failureText = QStringLiteral("Calibration applies only to analog sensors.");
        } else {
            const QString previousCoefficient = sensor.coefficient;
            sensor.coefficient = CalibrationMath::coefficientJson(fitResult.a,
                                                                  fitResult.b);

            CalibrationSession session;
            session.sensorId = sensorId;
            session.method = QStringLiteral("linear");
            session.a = fitResult.a;
            session.b = fitResult.b;
            session.r2 = fitResult.r2;
            session.maxResidual = fitResult.maxResidual;
            session.note = trimmedNote;
            session.createdBy = actor.userId;
            session.createdByUsername = actor.username;

            ok = calibrationDao.saveSession(session, dbPoints);
            if (ok)
                ok = sensorDao.save(sensor);
            if (ok)
                ok = configDao.bumpRevision() >= 0;
            if (ok) {
                QJsonObject detail = AuditTrail::changes(
                    {{QStringLiteral("coefficient"),
                      AuditTrail::safeCoefficient(previousCoefficient),
                      AuditTrail::safeCoefficient(sensor.coefficient)}});
                detail.insert(QStringLiteral("coefficientChanged"),
                              previousCoefficient != sensor.coefficient);
                detail.insert(QStringLiteral("pointCount"), parsed.size());
                if (fitResult.r2.has_value())
                    detail.insert(QStringLiteral("r2"), *fitResult.r2);
                if (fitResult.maxResidual.has_value())
                    detail.insert(QStringLiteral("maxResidual"), *fitResult.maxResidual);
                // Ghi chú tự do chỉ lưu trong phiên, không sao chép vào audit:
                // người vận hành có thể vô tình nhập dữ liệu nhạy cảm.
                AuditLogEntry entry = AuditTrail::entry(
                    actor, QStringLiteral("calibration.apply"), QStringLiteral("sensor"),
                    QString::number(sensorId), AuditResult::Ok, detail);
                ok = AuditTrail::append(sql, entry);
            }
            if (ok)
                ok = sql.commit();
            sessionId = session.id;
        }
        if (began && !ok)
            sql.rollback();
    }

    if (!ok) {
        emit messageSent(QStringLiteral("Calibration"), failureText);
        return failure(failureText);
    }

    // Nạp lại danh sách cảm biến để màn Monitor/Settings thấy hệ số mới; việc
    // này cũng khiến MonitorController khởi động lại polling với coefficient mới.
    if (SensorListModel *model = SensorListModel::instance())
        model->refresh();
    emit changed(sensorId);
    emit messageSent(QStringLiteral("Success"),
                     QStringLiteral("Calibration applied to sensor #%1.").arg(sensorId));

    QVariantMap out;
    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("sessionId"), sessionId);
    out.insert(QStringLiteral("pointCount"), parsed.size());
    out.insert(QStringLiteral("a"), fitResult.a);
    out.insert(QStringLiteral("b"), fitResult.b);
    out.insert(QStringLiteral("r2"), fitResult.r2.has_value()
                  ? QVariant(*fitResult.r2) : QVariant());
    out.insert(QStringLiteral("maxResidual"), fitResult.maxResidual.has_value()
                  ? QVariant(*fitResult.maxResidual) : QVariant());
    return out;
}
