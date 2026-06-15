import QtQuick.Controls
import QtQuick.Controls.Material

import DataLogger.Theme

// Flat tool button — text and icon use buttonText (black in dark mode).
ToolButton {
    Material.foreground: AppColors.buttonText
    icon.color: AppColors.buttonText
}
