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
    property Item popoutMaskItem: popout.maskItem
    property Item popoutParent: null
    property bool needsKeyboard: popout.needsKeyboard
    readonly property Item effectivePopoutParent: popoutParent ? popoutParent : root
    readonly property real effectiveHeight: root.height > 0 ? root.height : root.implicitHeight
    readonly property var popoutPosition: root.mapToItem(root.effectivePopoutParent, 0, root.effectiveHeight + 8)

    AppText {
        id: timeText
        anchors.centerIn: parent
        color: Theme.foregroundForItem(timeText)
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
        parent: root.effectivePopoutParent
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false
        
        // Позиционирование под часами (выравнивание по левому краю)
        x: root.popoutPosition.x
        y: root.popoutPosition.y
        z: 1000
        
        // Точка вылета анимации пузыря (смещена влево к часам)
        originX: 22
    }
}
