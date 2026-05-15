import QtQuick
import QtQuick.Window
import "../core"

Window {
    id: root

    property real spawnX: 0
    property real spawnY: 0

    default property alias content: contentArea.data

    width: 400
    height: 500
    visible: true
    color: "transparent"

    x: spawnX
    y: spawnY
    flags: Qt.FramelessWindowHint | Qt.Window
    title: "qs-media-standalone"

    onClosing: {
        close.accepted = false;
        contentArea.opacity = 0;
        closeTimer.start();
    }

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
