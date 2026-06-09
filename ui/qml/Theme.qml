pragma Singleton
import QtQuick

// Design token registry — all QML files MUST reference these tokens.
// Never hardcode colour literals outside this file.
// Aligned with Material 3 Dark colour scheme (custom palette).
QtObject {

    // ── Backgrounds / Surfaces ────────────────────────────────────────────
    readonly property color bgDeep:      "#131313"   // Window / status bar (M3: surface)
    readonly property color bgPanel:     "#1c1b1b"   // Cards, panels (M3: surfaceContainerLow)
    readonly property color bgStripe:    "#232323"   // Alternating rows (M3: surfaceContainer)
    readonly property color bgSeparator: "#2a2a2a"   // Dividers, chip bg (M3: surfaceContainerHigh)
    readonly property color bgInput:     "#2a2a2a"   // TextField / input bg
    readonly property color bgErrorTint: "#3a2020"   // Error chip / tinted bg

    // M3 alias set (used by new components)
    readonly property color surface:                bgDeep
    readonly property color surfaceContainerLow:    bgPanel
    readonly property color surfaceContainer:       bgStripe
    readonly property color surfaceContainerHigh:   bgSeparator
    readonly property color surfaceContainerHighest:"#313131"

    // ── Accent ───────────────────────────────────────────────────────────
    readonly property color accent:      "#558dff"   // Primary / active tab, borders
    readonly property color accentText:  "#b0c6ff"   // Titles, sensor names (M3: onPrimaryContainer)

    // M3 alias
    readonly property color primary:            accent
    readonly property color primaryContainer:   "#1e3a6e"
    readonly property color onPrimary:          "#ffffff"
    readonly property color onPrimaryContainer: accentText

    // ── Text ─────────────────────────────────────────────────────────────
    readonly property color textPrimary:      "#e5e2e1"  // Main content
    readonly property color textSecondary:    "#8c90a0"  // Labels, timestamps
    readonly property color textLabel:        "#8c90a0"  // Settings labels
    readonly property int   fontLabelSize:    14
    readonly property color textDim:          "#666666"  // Disabled-like, secondary timestamps
    readonly property color textFaint:        "#555555"  // Out-of-range calendar days
    readonly property color textOnColoredBtn: "#ffffff"  // Text on accent/start/stop buttons

    // M3 alias
    readonly property color onSurface:         textPrimary
    readonly property color onSurfaceVariant:  textSecondary
    readonly property color primaryText:       textPrimary

    // ── Status semantic colours ───────────────────────────────────────────
    readonly property color statusOk:         "#7dffa2"   // OK / collecting
    readonly property color statusErr:        "#ff6666"   // Error (soft)
    readonly property color statusErrBright:  "#ff4444"   // Critical dot
    readonly property color statusWarn:       "#b0c6ff"   // Pending / warning

    // M3 semantic alias
    readonly property color success: statusOk
    readonly property color error:   statusErr
    readonly property color warning: "#d4a62d"

    // ── Borders ───────────────────────────────────────────────────────────
    readonly property color borderOk:      "#2a6b3e"
    readonly property color borderErr:     "#a83232"
    readonly property color borderDefault: "#2a2a2a"

    readonly property color elevatedBorder: "#333333"  // Elevated pane outline

    // ── Buttons ───────────────────────────────────────────────────────────
    readonly property color btnStart:       "#2a6b3e"
    readonly property color btnStop:        "#a83232"
    readonly property color btnClear:       "#d4a62d"
    readonly property color btnClearText:   "#1a1a1a"
    readonly property color btnBgDisabled:  "#666666"
    readonly property color btnBgMuted:     "#444444"

    // ── Shape / Radius ────────────────────────────────────────────────────
    readonly property int radiusCard:   12   // M3 medium shape (cards, elevated panes)
    readonly property int radiusSmall:   6   // Chips, tags
    readonly property int radiusTiny:    4   // Dense items
    readonly property int radiusMedium:  8   // Buttons, taskbar items, list items (M3: small shape)
    readonly property int chipRadius:   12   // Status chips (M3)
    readonly property int listItemRadius: 8  // List row highlight

    // ── Spacing ───────────────────────────────────────────────────────────
    readonly property int spacingXS:   4
    readonly property int spacingS:    8
    readonly property int spacingM:   16
    readonly property int spacingL:   24
    readonly property int sectionSpacing: 20  // ElevatedPane default padding

    // ── Typography scale (pixel sizes) ───────────────────────────────────
    readonly property int typeTitleLarge:   22
    readonly property int typeTitleMedium:  16
    readonly property int typeBodyLarge:    16
    readonly property int typeBodyMedium:   14
    readonly property int typeLabelLarge:   14
    readonly property int typeLabelMedium:  12
    readonly property int typeLabelSmall:   11

    // ── Chart / Trending series palette ──────────────────────────────────
    readonly property var chartSeriesColors: [
        "#558dff", "#7dffa2", "#ff6666", "#d4a62d",
        "#b0c6ff", "#ff9933", "#cc66ff", "#66cccc",
    ]

    // Alias used by ChartGraphsTheme equivalent
    readonly property var graphSeriesColors: chartSeriesColors
}
