import QtQuick
import Quickshell
import "../../components"
import "../../core"

Item {
    id: root
    
    implicitWidth: timeText.implicitWidth
    implicitHeight: 30
    
    property bool popoutOpen: false
    property Item popoutItem: popout

    AppText {
        id: timeText
        anchors.centerIn: parent
        color: Theme.textDark
        font {
            pixelSize: 24
            weight: Font.Black
            family: Theme.fontClock
            letterSpacing: 0.5
        }
        
        text: TimeState.currentTime

        MouseArea {
            anchors.fill: parent
            onClicked: root.popoutOpen = !root.popoutOpen
            
            onPressed: timeText.opacity = 0.6
            onReleased: timeText.opacity = 1.0
        }
    }

    ClockPopout {
        id: popout
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false
        
        // Позиционирование под часами (выравнивание по левому краю)
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        
        // Точка вылета анимации пузыря (смещена влево к часам)
        originX: 22
    }
}
