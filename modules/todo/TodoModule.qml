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

    Rectangle {
        id: btnRect
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 10
        color: btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: "" // Иконка Taskwarrior (Nerd Font)
            color: root.popoutOpen ? Theme.info : Theme.textDark
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
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false
        
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        
        originX: 16 // Центр иконки
    }
}
