import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import DataLogger.Theme
import DataLogger.Components

/*
 * Unified application button.
 *
 * One component for every action button (icons, text, or both). Always has a
 * background — never a bare icon. Replaces hand-rolled `Button { background; contentItem }`.
 *
 * Content (any combination):
 *   - iconName : Material Symbols glyph name (optional)
 *   - text     : label (optional)
 * If only iconName is set the button renders as a square icon button (still with a background).
 *
 * Style (variant) — controls the background:
 *   - "filled"   : solid `accent` fill (default). Use for primary / colored actions.
 *   - "tonal"    : muted neutral fill. Use for secondary actions.
 *   - "outlined" : panel fill + 1px border. Use for low-emphasis actions.
 *   `accent` sets the filled color and the active-state highlight.
 *
 * State:
 *   - enabled : built-in. Disabled buttons get a muted background + faded content.
 *   - active  : highlight (e.g. toggle/segmented). Defaults to `checked` so checkable
 *               buttons light up automatically.
 */
AbstractButton {
    id: control

    property string iconName: ""
    property int iconSize: 18
    property bool iconSpinning: false

    property string variant: "filled"   // "filled" | "tonal" | "outlined"
    property color accent: AppColors.primaryColor

    property bool active: control.checked

    readonly property bool iconOnly: text === "" && iconName !== ""

    font.pixelSize: AppTypography.bodyMedium.pixelSize
    font.weight: Font.Medium
    hoverEnabled: true

    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0

    implicitHeight: AppTheme.buttonHeight
    implicitWidth: iconOnly
        ? AppTheme.iconButtonSize
        : (contentRow.implicitWidth + leftPadding + rightPadding)
    padding: iconOnly ? 0 : Theme.spacingM

    // Content color: filled sits on a strong fill (black-on-tint in dark mode);
    // tonal/outlined sit on dark surfaces, so use light text — accent fg when active.
    readonly property color _contentColor: !enabled
        ? AppColors.disabledContent
        : variant === "filled" ? AppColors.buttonTextOnFilled
        : active ? AppColors.accentContainerFg
        : AppColors.primaryText

    background: Rectangle {
        // Match central_logger shape: pill ends for labelled buttons, rounded square for icon-only.
        radius: control.iconOnly ? AppTheme.chipRadius : AppTheme.buttonRadius
        opacity: control.pressed ? 0.75 : 1.0

        color: !control.enabled
            ? (control.variant === "filled" ? Theme.btnBgDisabled : Theme.btnBgMuted)
            : control.variant === "filled"  ? control.accent
            : control.variant === "tonal"   ? (control.active ? AppColors.accentContainer : Theme.bgSeparator)
            : /* outlined */                   (control.active ? AppColors.accentContainer : Theme.bgPanel)

        border.width: control.variant === "outlined" ? 1 : 0
        border.color: Theme.borderDefault

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: control.enabled && control.hovered && !control.pressed
            color: AppColors.hoverFill
        }

        Behavior on color {
            ColorAnimation { duration: AppTheme.motionFast }
        }
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            UiIcon {
                id: btnIcon
                visible: control.iconName !== ""
                name: control.iconName
                size: control.iconSize
                iconColor: control._contentColor
                rotation: 0
                Layout.alignment: Qt.AlignVCenter

                RotationAnimator {
                    target: btnIcon
                    from: 0
                    to: 360
                    duration: AppTheme.motionPulse
                    loops: Animation.Infinite
                    running: control.iconSpinning
                    onStopped: btnIcon.rotation = 0
                }
            }

            Text {
                visible: control.text !== ""
                text: control.text
                font: control.font
                color: control._contentColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
