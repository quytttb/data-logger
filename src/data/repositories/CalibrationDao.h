#pragma once
#include "data/models/CalibrationSession.h"
#include <QList>
#include <QSqlDatabase>
#include <optional>

// Lưu/lịch sử hiệu chuẩn tuyến tính đa điểm.
//
// saveSession() KHÔNG tự mở transaction: caller (controller) phải bọc cùng
// transaction với việc cập nhật sensor.coefficient và ghi audit, để không có
// trạng thái "đã lưu điểm nhưng chưa đổi hệ số" hoặc ngược lại.
class CalibrationDao {
public:
    explicit CalibrationDao(QSqlDatabase db);

    // Kiểm tra N>=2, raw/reference hữu hạn, a/b hữu hạn. Gán session.id,
    // pointCount và id cho từng điểm. Không commit.
    bool saveSession(CalibrationSession &session, const QList<CalibrationPoint> &points);

    // Lịch sử gần nhất của một cảm biến (không kèm điểm).
    QList<CalibrationSession> recentSessions(int sensorId, int limit = 50) const;
    std::optional<CalibrationSession> latestForSensor(int sensorId) const;
    QList<CalibrationPoint> pointsForSession(int sessionId) const;
    int countForSensor(int sensorId) const;

    // Xóa phiên + điểm (FK ON DELETE CASCADE). Không đụng sensor.coefficient.
    bool removeSession(int id);

private:
    QSqlDatabase m_db;
    static CalibrationSession rowToSession(const class QSqlRecord &record);
};
