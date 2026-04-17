import QtQuick
import "../core"

Item {
    id: root

    default property alias content: contentHost.data

    property real dismissThreshold: 100
    property int snapBackInterval: AnimationConfig.timerSnapBack
    property real fadeFactor: 0.7

    property real dragOffsetX: 0.0
    property real dragOffsetY: 0.0
    property bool isDragging: false

    readonly property real dragDistance: Math.sqrt(dragOffsetX * dragOffsetX + dragOffsetY * dragOffsetY)
    readonly property real visualOffsetX: isDragging ? dragOffsetX : 0
    readonly property real visualOffsetY: isDragging ? dragOffsetY : 0
    readonly property real dragOpacity: isDragging ? Math.max(0.0, 1.0 - (dragDistance / dismissThreshold) * fadeFactor) : 1.0

    signal dragStarted()
    signal dismissed()

    function reset() {
        snapBackTimer.stop()
        dragOffsetX = 0
        dragOffsetY = 0
        isDragging = false
    }

    DragHandler {
        id: dragHandler
        target: null
        enabled: root.enabled

        onTranslationChanged: function() {
            if (!root.isDragging)
                root.dragStarted()
            root.isDragging = true
            root.dragOffsetX = translation.x
            root.dragOffsetY = translation.y
        }

        onActiveChanged: {
            if (!active) {
                if (root.dragDistance > root.dismissThreshold) {
                    root.dismissed()
                } else {
                    root.isDragging = false
                    snapBackTimer.start()
                }
            }
        }
    }

    Timer {
        id: snapBackTimer
        interval: root.snapBackInterval
        repeat: false
        onTriggered: {
            root.dragOffsetX = 0
            root.dragOffsetY = 0
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
