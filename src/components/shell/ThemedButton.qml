import QtQuick.Controls
import QtQuick.Controls.Material

import DataLogger.Theme

// Standard Material Button — text and icon use buttonText (black in dark mode).
Button {
    Material.foreground: AppColors.buttonText
    icon.color: AppColors.buttonText
}
