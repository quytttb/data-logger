pragma Singleton
import QtQuick

import LoggerKit.Theme

// Edge-only Digital I/O (DI/DO) indicator colors — Monitor cards & sensor
// link rows. Not part of the shared kit (central_logger has no DI/DO UI).
QtObject {
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
}
