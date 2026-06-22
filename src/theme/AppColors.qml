pragma Singleton
import QtQuick

import DataLogger.Core

// M3 color roles + state layers (dark theme only).
// ApplicationWindow sets Material.primary/accent from AppTheme — custom UI uses tokens here only.
QtObject {
    readonly property real hoverOpacity:    0.08
    readonly property real dividerOpacity:  0.12

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function hoverLayer(base) {
        return withAlpha(base, hoverOpacity)
    }

    function divider(base) {
        return withAlpha(base, dividerOpacity)
    }

    // Brand (Teal / Indigo) — keep in sync with AppTheme Material.primary / Material.accent on window.
    readonly property color primaryColor: "#80CBC4"
    readonly property color accentColor:  "#9FA8DA"
    readonly property color onPrimary:    "#FFFFFF"

    /// Button labels — black for contrast on tinted Material/filled buttons.
    readonly property color buttonText: "#000000"
    readonly property color buttonTextOnFilled: "#000000"
    readonly property color buttonIcon: buttonText
    readonly property color buttonIconOnFilled: buttonTextOnFilled

    // Solid containers (alpha-only blends were too low-contrast on rail / tonal buttons).
    readonly property color accentContainer:   "#3D4F7C"
    // Not "onAccentContainer" — QML reserves on<Property> when property "accentContainer" exists.
    readonly property color accentContainerFg: "#E8EAF6"

    // primaryText — not "onSurface" (clashes with Qt Material).
    readonly property color primaryText: "#E6E1E5"
    readonly property color onSurfaceVariant: "#CAC4D0"

    readonly property color hoverFill: hoverLayer(primaryText)
    readonly property color dividerLine: divider(primaryText)

    // Text emphasis (prefer over Label.opacity in views).
    readonly property color textMuted: onSurfaceVariant
    readonly property color textSubtle: withAlpha(primaryText, 0.75)
    readonly property color textFaint: withAlpha(primaryText, 0.6)
    readonly property color textSoft: withAlpha(primaryText, 0.85)
    readonly property color disabledContent: withAlpha(primaryText, 0.38)
    readonly property color emptyStateIcon: withAlpha(onSurfaceVariant, 0.55)
    readonly property color iconSubtle: withAlpha(onSurfaceVariant, 0.5)
    readonly property color tableCellMuted: withAlpha(primaryText, 0.8)
    readonly property color tableHeaderText: withAlpha(primaryText, 0.7)

    readonly property color surface:              "#111318"
    readonly property color surfaceContainerLow:  "#282828"
    readonly property color surfaceContainer:     "#323232"

    /// Navigation rail surface — slightly raised from the main canvas.
    readonly property color navRail:              "#1E2024"
    readonly property color surfaceContainerHigh: "#3D3D3D"

    readonly property color elevatedBorder: "#3A3A3A"

    readonly property color outline:        "#938F99"
    readonly property color outlineVariant: "#49454F"

    readonly property color error:            "#FFB4AB"
    readonly property color errorContainer:   "#93000A"
    readonly property color errorContainerFg: "#FFDAD6"

    readonly property color warning:          "#FFD270"
    readonly property color warningContainer: "#8A6A00"

    readonly property color success:          "#81C784"
    readonly property color successContainer: "#1B5E20"

    readonly property color info: "#90CAF9"

    // Digital I/O (DI/DO) indicators — Monitor cards & sensor link rows.
    readonly property color diStrong:         "#1E88E5"   // DI badge background
    readonly property color diActive:         "#42A5F5"   // DI accent / border / label
    readonly property color diOnBg:           "#1565C0"   // DI ON-state circle fill
    readonly property color diTint:           "#103010"   // DI link-row tint
    readonly property color doStrong:         "#C62828"   // DO badge / DO ON-state circle fill
    readonly property color doActive:         "#EF5350"   // DO accent / border / label
    readonly property color doTint:           "#301010"   // DO link-row tint
    readonly property color ioInactive:       "#616161"   // OFF-state fill
    readonly property color ioInactiveBorder: "#9E9E9E"   // OFF-state border
    readonly property color ioFallback:       "#888888"   // unknown DI dot fallback

    /// Alias used in some views
    readonly property color textSecondary: onSurfaceVariant

    /// Accent color for system_event rows (`displayLevel` from RecentEventsModel).
    function severityColor(displayLevel) {
        switch ((displayLevel || "").toLowerCase()) {
        case "critical":
        case "error":
            return error
        case "warning":
            return warning
        case "info":
            return info
        default:
            return onSurfaceVariant
        }
    }

    function eventLevelBackground(displayLevel) {
        const c = severityColor(displayLevel)
        return withAlpha(c, 0.12)
    }

    readonly property var graphSeriesColors: [
        "#4DB6AC", "#9FA8DA", "#4FC3F7", "#FFB74D",
        "#CE93D8", "#F48FB1", "#64B5F6", "#81C784"
    ]
}
