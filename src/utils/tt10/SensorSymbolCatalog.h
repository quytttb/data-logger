#pragma once
#include <QStringList>

// Thông tư 10/2021/TT-BTNMT — Phụ lục 15, Bảng 34
// Quy định ký hiệu thông số đo và đơn vị đo tương ứng (nước, khí thải, không khí).
// App map vào sensor.sensor_symbol (ký hiệu cảm biến) — giá trị ghi cột 1 file truyền FTP.

namespace SensorSymbolCatalog {

inline QStringList allSymbols()
{
    return {
        QStringLiteral("Flow"),
        QStringLiteral("Temp"),
        QStringLiteral("Color"),
        QStringLiteral("pH"),
        QStringLiteral("TSS"),
        QStringLiteral("COD"),
        QStringLiteral("NH4"),
        QStringLiteral("TP"),
        QStringLiteral("TN"),
        QStringLiteral("TOC"),
        QStringLiteral("Cl"),
        QStringLiteral("RH"),
        QStringLiteral("P"),
        QStringLiteral("NO"),
        QStringLiteral("NO2"),
        QStringLiteral("CO"),
        QStringLiteral("SO2"),
        QStringLiteral("O2"),
        QStringLiteral("H2S"),
        QStringLiteral("NH3"),
        QStringLiteral("VHg"),
        QStringLiteral("PM"),
        QStringLiteral("O3"),
        QStringLiteral("PM10"),
        QStringLiteral("PM2,5"),
    };
}

} // namespace SensorSymbolCatalog
