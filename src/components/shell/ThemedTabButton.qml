import QtQuick.Controls
import QtQuick.Controls.Material

import DataLogger.Theme

// Tab bar button — label and icon use buttonText (black in dark mode).
TabButton {
    Material.foreground: AppColors.buttonText
    icon.color: AppColors.buttonText
}
