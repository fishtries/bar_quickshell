import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root

    property real spawnX: 0
    property real spawnY: 0

    default property alias content: contentArea.data

    implicitWidth: 400
    implicitHeight: 500
    color: "transparent"

    anchors.top: true
    anchors.left: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-standalone"
    WlrLayershell.exclusiveZone: -1

    margins.top: spawnY
    margins.left: spawnX

    Item {
        id: contentArea
        anchors.fill: parent
        opacity: 0.0

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
        }

        Component.onCompleted: contentArea.opacity = 1.0
    }

    function closeWindow() {
        contentArea.opacity = 0;
        closeTimer.start();
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.destroy()
    }
}
