#include "utils/chart/Downsampler.h"
#include <algorithm>

namespace Downsampler {

QVector<TrendPoint> minMax(const QVector<TrendPoint> &in, int maxPoints,
                           const QVector<char> &isAlarm)
{
    const int n = in.size();
    if (n == 0)
        return {};
    if (maxPoints < 4) {
        // Ngưỡng quá nhỏ: giữ đầu + cuối + neo alarm (không drop alarm).
        if (n <= 2)
            return in;
        QVector<int> tiny{0, n - 1};
        const int m = qMin(isAlarm.size(), n);
        for (int i = 0; i < m; ++i) {
            if (isAlarm[i])
                tiny.append(i);
        }
        std::sort(tiny.begin(), tiny.end());
        tiny.erase(std::unique(tiny.begin(), tiny.end()), tiny.end());
        QVector<TrendPoint> out;
        out.reserve(tiny.size());
        for (int idx : tiny)
            out.append(in[idx]);
        return out;
    }
    if (n <= maxPoints)
        return in;

    // Số bucket: mỗi bucket emit min + max → 2*k + 2 (đầu/cuối) ≈ maxPoints.
    const int k = (maxPoints - 2) / 2;
    QVector<int> kept;
    kept.reserve(maxPoints + isAlarm.size());
    kept.append(0);

    // Chia điểm nội bộ [1, n-2] thành k bucket bằng phép chia nguyên —
    // bucket rỗng (khi n-2 < k) tự bỏ qua, không cần nhánh đặc biệt.
    for (int b = 0; b < k; ++b) {
        const int lo = 1 + (b * (n - 2)) / k;
        const int hi = 1 + ((b + 1) * (n - 2)) / k;
        if (lo >= hi)
            continue;
        int minIdx = lo, maxIdx = lo;
        for (int i = lo + 1; i < hi; ++i) {
            if (in[i].y < in[minIdx].y) minIdx = i;
            if (in[i].y > in[maxIdx].y) maxIdx = i;
        }
        // Emit theo thứ tự thời gian (min trước hay max trước tùy dữ liệu).
        if (minIdx == maxIdx) {
            kept.append(minIdx);
        } else if (minIdx < maxIdx) {
            kept.append(minIdx);
            kept.append(maxIdx);
        } else {
            kept.append(maxIdx);
            kept.append(minIdx);
        }
    }
    kept.append(n - 1);

    // Neo alarm: mọi điểm báo động luôn xuất hiện trên graph.
    const int m = qMin(isAlarm.size(), n);
    for (int i = 0; i < m; ++i) {
        if (isAlarm[i])
            kept.append(i);
    }

    std::sort(kept.begin(), kept.end());
    kept.erase(std::unique(kept.begin(), kept.end()), kept.end());

    QVector<TrendPoint> out;
    out.reserve(kept.size());
    for (int idx : kept)
        out.append(in[idx]);
    return out;
}

} // namespace Downsampler
