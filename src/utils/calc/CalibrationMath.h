#pragma once

#include <QList>
#include <QString>
#include <optional>

// Hồi quy tuyến tính bình phương tối thiểu cho hiệu chuẩn cảm biến.
//
// Pure math, không phụ thuộc DB/QML để test được bằng CTest. Kết quả vẫn được
// ghi vào sensor.coefficient dạng {"a":..,"b":..} — đúng định dạng
// Formula::applyFormula đang dùng ở runtime, không phải hồi quy mỗi lần poll.
namespace CalibrationMath {

struct Point {
    double raw = 0.0;        // giá trị thô đọc từ Modbus
    double reference = 0.0;  // giá trị chuẩn của thiết bị hiệu chuẩn
};

struct FitResult {
    bool ok = false;
    QString error;

    double a = 1.0;
    double b = 0.0;

    // R² không xác định khi mọi reference bằng nhau (SStot = 0) — khi đó
    // đường thẳng vẫn hợp lệ nhưng không có ý nghĩa "độ khớp".
    std::optional<double> r2;
    std::optional<double> maxResidual;   // max |reference - (a*raw + b)|
    QList<double> residuals;             // cùng thứ tự với points đầu vào
};

// Kiểm tra N>=2, raw đủ biến thiên, mọi giá trị hữu hạn, a/b không tràn số.
FitResult fit(const QList<Point> &points);

// {"a":..,"b":..} — compact, đúng thứ tự key ổn định để test/so sánh.
QString coefficientJson(double a, double b);

// Đọc {"a":..,"b":..} (cũng chấp nhận JSON có thêm key khác). Trả false nếu
// JSON sai cấu trúc hoặc a/b không hữu hạn; khi đó *a/*b giữ nguyên.
bool parseCoefficient(const QString &json, double *a, double *b);

} // namespace CalibrationMath
