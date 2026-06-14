import QtGraphs
import QtQuick

import DataLogger.Components

GraphsView {
    id: root

    marginBottom: 8
    marginLeft: 8
    theme: ChartGraphsTheme {}

    readonly property alias chart: root
}
