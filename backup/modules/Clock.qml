import QtQuick
import Quickshell

Item {
    id: root
    
    implicitWidth: timeText.implicitWidth
    implicitHeight: 30
    
    Text {
        id: timeText
        anchors.centerIn: parent
        color: "#1f1f1f"
        font {
            pixelSize: 24
            weight: Font.Black
            family: "MariosBlack" // Или Inter, если Outfit нет
            letterSpacing: 0.5
        }
        
        text: root.currentTime
    }
    
    property string currentTime: Qt.formatTime(new Date(), "HH:mm")
    
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "HH:mm")
    }
}
