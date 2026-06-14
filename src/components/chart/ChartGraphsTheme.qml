import QtGraphs

import DataLogger.Theme

GraphsTheme {
    colorScheme: AppTheme.isLightTheme ? GraphsTheme.ColorScheme.Light : GraphsTheme.ColorScheme.Dark
    backgroundColor: AppColors.surfaceContainerLow
    plotAreaBackgroundColor: AppColors.surfaceContainerLow
    seriesColors: AppColors.graphSeriesColors
    labelTextColor: AppColors.onSurfaceVariant
}
