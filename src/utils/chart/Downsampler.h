#pragma once
#include <QVector>

// Downsampling min-max bucket (M4) cho trending graph lịch sử.
//
// Mỗi bucket phát ra điểm min + điểm max (sắp lại theo thời gian) nên
// envelope/đỉnh/alarm luôn được giữ — đúng cho forensics công nghiệp.
// Giữ nguyên thứ tự thời gian, luôn giữ điểm đầu/cuối.
//
// Pure, không dính SQL/QML/thread — test được bằng Qt Test.
struct TrendPoint {
    double x = 0; // timestamp ms
    double y = 0; // giá trị
};

namespace Downsampler {
// Số điểm render mục tiêu cho màn kiosk 1024px (1 bucket ~ 2-3px).
inline constexpr int kDefaultMaxPoints = 800;

// Thu gọn `in` (đã sắp theo x tăng dần) về tối đa ~maxPoints điểm.
// - n <= maxPoints: trả nguyên, không downsample.
// - isAlarm[i] == true: điểm đó luôn được giữ (neo alarm), tính thêm
//   ngoài maxPoints (alarm thường thưa nên không đáng kể). Kể cả khi
//   maxPoints < 4 (chỉ còn đầu + cuối + alarm).
// - Trả về rỗng nếu in rỗng.
QVector<TrendPoint> minMax(const QVector<TrendPoint> &in, int maxPoints = kDefaultMaxPoints,
                           const QVector<char> &isAlarm = {});
}
