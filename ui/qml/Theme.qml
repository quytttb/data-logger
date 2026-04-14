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

    // ── Radius ───────────────────────────────────────────────────────────
    readonly property int radiusCard:  10
    readonly property int radiusSmall:  6
    readonly property int radiusTiny:   4
}
