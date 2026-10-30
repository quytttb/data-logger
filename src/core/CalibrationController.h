#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include "utils/qml/QmlSingleton.h"

// Hiệu chuẩn tuyến tính đa điểm cho cảm biến analog.
//
// - fit() chỉ tính toán (không ghi DB) để QML xem trước a, b, R², sai số.
// - apply() lưu phiên + điểm, cập nhật sensor.coefficient, bump config_revision
//   và ghi audit trong CÙNG một transaction. Runtime vẫn đọc {"a","b"} từ
//   sensor.coefficient như trước — không hồi quy ở mỗi lần poll.
// - Quyền: xem lịch sử cần ViewData; áp dụng cần Calibrate (operator/admin).
class CalibrationController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit CalibrationController(QObject *parent = nullptr);

    DECLARE_QML_SINGLETON(CalibrationController)

    // points: [{raw, reference}, ...] — nhận cả number lẫn chuỗi số (dấu phẩy
    // thập phân được chấp nhận). Trả {ok, error, a, b, r2, maxResidual,
    // residuals[]}.
    Q_INVOKABLE QVariantMap fit(const QVariantList &points) const;

    // Hệ số hiện tại + phiên gần nhất: {ok, error, a, b, coefficient,
    // hasPoints, lastSession{...}}.
    Q_INVOKABLE QVariantMap current(int sensorId) const;

    // Lịch sử gần nhất (mới trước), tối đa 20 phiên.
    Q_INVOKABLE QVariantList history(int sensorId) const;
    Q_INVOKABLE QVariantList sessionPoints(int sessionId) const;

    // Áp dụng hiệu chuẩn. Trả {ok, error, sessionId, a, b, r2, maxResidual,
    // pointCount}.
    Q_INVOKABLE QVariantMap apply(int sensorId, const QVariantList &points,
                                  const QString &note);

signals:
    // Phát sau khi DB đã đổi để QML làm mới phần đang hiển thị.
    void changed(int sensorId);
    void messageSent(QString title, QString body);
};
