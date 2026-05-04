import QtQuick
import "../../core"
import "." as Aside

Item {
    id: root

    implicitWidth: 32
    implicitHeight: 32

    property bool needsKeyboard: Aside.AsideState.inputRequested

    function toggleIsland() {
        if (IslandState.isAside && Aside.AsideState.inputRequested) {
            Aside.AsideState.closeIsland()
            return
        }

        Aside.AsideState.requestTextInput()
        Aside.AsideState.refreshStatus()
    }

    Rectangle {
        id: btnRect
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 10
        color: btnMouse.containsMouse || IslandState.isAside ? Theme.localHoverForItem(btnRect) : "transparent"
        border.color: Aside.AsideState.isBusy ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.5) : "transparent"
        border.width: Aside.AsideState.isBusy ? 1 : 0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: Aside.AsideState.phase === "listening" ? "󰍬" : Aside.AsideState.isBusy ? "󰙴" : "󰚩"
            color: Aside.AsideState.errorMessage !== "" ? Theme.warning : Aside.AsideState.isBusy || IslandState.isAside ? Theme.info : Theme.foregroundForItem(parent)
            font.family: Theme.fontIcon
            font.pixelSize: 18
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            width: 7
            height: 7
            radius: 4
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 3
            anchors.bottomMargin: 3
            color: Aside.AsideState.daemonAvailable && Aside.AsideState.bridgeReady ? Theme.success : Theme.warning
            opacity: IslandState.isAside || btnMouse.containsMouse || !Aside.AsideState.daemonAvailable ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(event) {
                if (event.button === Qt.RightButton)
                    Aside.AsideState.startMic()
                else
                    root.toggleIsland()
            }
        }
    }
}
