pragma Singleton
import QtQuick

QtObject {
    // ── Backgrounds ──────────────────────────────────────────────────────
    readonly property color bgDeep:      "#131313"   // App window / status bar
    readonly property color bgPanel:     "#1c1b1b"   // Sidebar, cards, panels
    readonly property color bgStripe:    "#232323"   // Alternating list rows
    readonly property color bgSeparator: "#2a2a2a"   // Dividers, chip, headers
    readonly property color bgInput:     "#2a2a2a"   // TextField / input bg

    // ── Accent ───────────────────────────────────────────────────────────
    readonly property color accent:      "#558dff"   // Active tab bar, borders, highlights
    readonly property color accentText:  "#b0c6ff"   // Titles, sensor names

    // ── Text ─────────────────────────────────────────────────────────────
    readonly property color textPrimary:   "#e5e2e1" // Main content text
    readonly property color textSecondary: "#8c90a0" // Labels, units, timestamps
    readonly property color textLabel:     "#8c90a0" // Settings labels (reverted color for contrast)
    readonly property int   fontLabelSize: 14        // Settings labels font size
    readonly property color textDim:       "#666666" // Nhãn phụ / timestamp nhỏ (gần disabled)
    readonly property color textFaint:     "#555555" // RAW, ngày lịch ngoài tháng hiện tại
    readonly property color textOnColoredBtn: "#ffffff" // Chữ trên nút accent / start / stop

    // ── Status ───────────────────────────────────────────────────────────
    readonly property color statusOk:     "#7dffa2"  // OK / collecting
    readonly property color statusErr:    "#ff6666"  // Error (softer)
    readonly property color statusErrBright: "#ff4444" // Error dot / critical
    readonly property color statusWarn:   "#b0c6ff"  // FTP pending / warning

    // ── Border helpers ───────────────────────────────────────────────────
    readonly property color borderOk:      "#2a6b3e"
    readonly property color borderErr:     "#a83232"
    readonly property color borderDefault: "#2a2a2a"

    // ── Button backgrounds ───────────────────────────────────────────────
    readonly property color btnStart: "#2a6b3e"
    readonly property color btnStop:  "#a83232"
    readonly property color btnClear: "#d4a62d"   // Xóa bảng / cảnh báo nhẹ
    readonly property color btnClearText: "#1a1a1a"
    readonly property color btnBgDisabled:   "#666666" // Nền nút khi disabled / connecting
    readonly property color btnBgMuted:      "#444444" // Nền nút secondary khi disabled
    readonly property color bgErrorTint:     "#3a2020" // Chip / vùng nền lỗi nhẹ

    // ── Radius ───────────────────────────────────────────────────────────
    readonly property int radiusCard:  10
    readonly property int radiusSmall:  6
    readonly property int radiusTiny:   4
    readonly property int radiusMedium: 8 // Taskbar buttons, legacy 8px rounds

    // ── Chart (History line series) — trùng palette đã dùng trong HistoryView ──
    readonly property var chartSeriesColors: [
        "#558dff", "#7dffa2", "#ff6666", "#d4a62d",
        "#b0c6ff", "#ff9933", "#cc66ff", "#66cccc",
    ]
}
