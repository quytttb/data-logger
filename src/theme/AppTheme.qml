pragma Singleton
import QtQuick
import QtQuick.Controls.Material

import DataLogger.Core

// Material palette + layout tokens for ApplicationWindow.
QtObject {
    readonly property int accent:  Material.Indigo
    readonly property int primary: Material.Teal

    readonly property int materialTheme: Material.Dark

    readonly property int railWidth:            80
    readonly property int topBarHeight:         80
    readonly property int pagePadding:          24          // content horizontal inset (desktop safe)
    readonly property int pageTopSpacing:       16          // below top bar
    readonly property int sectionSpacing:       16          // between major blocks
    readonly property int toolbarGap:            8          // icons/actions in *TopBar
    readonly property int formRowSpacing:       16          // Settings grid / dialog fields
    readonly property int dialogPadding:        24
    readonly property int navItemHeight:        72
    readonly property int navItemSpacing:        4
    readonly property int tableHeaderHeight:    40
    readonly property int detailWideBreakpoint: 950
    readonly property int dialogFormWideBreakpoint:720    // LoggerFormDialog: 4-col field pairs
    readonly property int dialogMaxWidth:              880
    readonly property int dialogNarrowMaxWidth:        520

    // M3 shape — 1 dp ≈ 1 px (Qt Material roundedScale is inconsistent when background is custom).
    readonly property int cardRadius:         12          // pane / card chrome
    readonly property int chipRadius:           12          // chips, badges
    readonly property int listItemRadius:        8          // dense list rows, tooltips
    readonly property int buttonHeight:       48          // M3 min touch target (≥48dp) for finger input
    readonly property int buttonRadius:       24          // full round ends on 48dp buttons
    readonly property int buttonPaddingH:     24
    readonly property int iconButtonSize:     48          // square icon-only touch target (≥48dp)
    readonly property int iconSizeSm:         16          // dense inline icons
    readonly property int iconSizeMd:         20          // default action icons
    readonly property int iconSizeLg:         24          // prominent / nav icons
    readonly property int navPillHeight:        32
    readonly property int navPillWidth:         56
    readonly property int navPillRadius:        16

    // Motion durations (ms)
    readonly property int motionFast:          120         // state-layer / color transitions
    readonly property int motionStandard:      150         // standard color/opacity transitions
    readonly property int motionPulse:        1000         // looping spinner / pulse

    /// Distribute totalWidth across columns: each gets at least minimums[i].
    /// Extra width goes only to columns with weights[i] > 0 (0 = fixed at minimum).
    /// Returned widths always sum to totalWidth (integer px).
    function distributeColumnWidths(totalWidth, weights, minimums) {
        const n = weights.length
        if (n === 0 || totalWidth <= 0)
            return []

        let sumMin = 0
        let flexWeight = 0
        for (let col = 0; col < n; ++col) {
            sumMin += minimums[col]
            if (weights[col] > 0)
                flexWeight += weights[col]
        }

        const widths = []
        if (totalWidth <= sumMin) {
            for (let col = 0; col < n; ++col)
                widths.push(totalWidth * minimums[col] / sumMin)
        } else if (flexWeight <= 0) {
            for (let col = 0; col < n; ++col)
                widths.push(minimums[col])
        } else {
            const extra = totalWidth - sumMin
            for (let col = 0; col < n; ++col) {
                if (weights[col] <= 0)
                    widths.push(minimums[col])
                else
                    widths.push(minimums[col] + extra * weights[col] / flexWeight)
            }
        }

        let sum = 0
        for (let col = 0; col < n; ++col) {
            widths[col] = Math.floor(widths[col])
            sum += widths[col]
        }
        let drift = totalWidth - sum
        for (let col = 0; drift > 0 && col < n; ++col) {
            if (weights[col] > 0) {
                widths[col] += 1
                --drift
            }
        }
        for (let col = 0; drift > 0 && col < n; ++col) {
            widths[col] += 1
            --drift
        }

        return widths
    }
}
