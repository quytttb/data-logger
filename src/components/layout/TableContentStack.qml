import QtQuick

Item {
    id: root

    property bool hasData: true
    property string emptyMessage: ""

    default property alias dataContent: dataLayer.data

    Item {
        id: dataLayer
        anchors.fill: parent
        visible: root.hasData
    }

    EmptyStatePlaceholder {
        anchors.fill: parent
        visible: !root.hasData
        message: root.emptyMessage
    }
}
