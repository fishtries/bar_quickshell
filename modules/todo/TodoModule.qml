import QtQuick
import Quickshell
import "../../components"
import "../../core"

Item {
    id: root
    
    implicitWidth: 32
    implicitHeight: 32
    
    property bool popoutOpen: false
    property Item popoutItem: popout
    property Item popoutMaskItem: popout.maskItem
    property Item popoutParent: null
    property real popoutTopY: 0
    property real popoutHorizontalOffset: 113
    readonly property Item effectivePopoutParent: popoutParent ? popoutParent : root
    readonly property real effectiveHeight: root.height > 0 ? root.height : root.implicitHeight
    readonly property var popoutPosition: root.mapToItem(root.effectivePopoutParent, root.popoutHorizontalOffset, root.popoutTopY > 0 ? root.popoutTopY - root.mapToItem(root.effectivePopoutParent, 0, 0).y : root.effectiveHeight + 24)
    readonly property real popoutOriginX: Math.max(20, root.mapToItem(root.effectivePopoutParent, root.implicitWidth / 2, 0).x - root.popoutPosition.x)

    Rectangle {
        id: btnRect
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 10
        color: btnMouse.containsMouse ? Theme.localHoverForItem(btnRect) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: "" // Иконка Taskwarrior (Nerd Font)
            color: root.popoutOpen ? Theme.info : Theme.foregroundForItem(parent)
            font.family: Theme.fontIcon
            font.pixelSize: 18
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popoutOpen = !root.popoutOpen
        }
    }

    TodoPopout {
        id: popout
        parent: root.effectivePopoutParent
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false
        x: root.popoutPosition.x
        y: root.popoutPosition.y
        z: 1000
        
        originX: root.popoutOriginX
    }
}
