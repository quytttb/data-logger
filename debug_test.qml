import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    width: 600; height: 400; visible: true
    
    property int sensorSubTabIndex: 0
    
    TabBar {
        id: bar
        currentIndex: sensorSubTabIndex
        onCurrentIndexChanged: {
            if (currentIndex !== sensorSubTabIndex) {
                console.log("Tab changed to", currentIndex)
                sensorSubTabIndex = currentIndex
            }
        }
        TabButton { text: "Basic" }
        TabButton { text: "Scaling" }
    }
    
    StackLayout {
        anchors.top: bar.bottom; anchors.bottom: parent.bottom; width: parent.width
        currentIndex: sensorSubTabIndex
        Rectangle { color: "red"; Text { text: "0" } }
        Rectangle { color: "blue"; Text { text: "1" } }
    }
}
