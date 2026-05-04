import QtQuick
import QtQuick.Effects
import "../../core"

Item {
    id: root

    property real level: 0.0
    property bool active: false
    property real tick: 0.0

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function random(index, salt) {
        const value = Math.sin((index + 1) * (salt + 12.9898)) * 43758.5453
        return value - Math.floor(value)
    }

    implicitWidth: 176
    implicitHeight: 42
    opacity: active ? 1.0 : 0.68

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    Timer {
        interval: 16
        repeat: true
        running: root.active || root.level > 0.01
        onTriggered: root.tick += 0.06 + root.clamp(root.level, 0, 1) * 0.12
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.06 + root.clamp(root.level, 0, 1) * 0.05)
        border.width: 1
        border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.10 + root.clamp(root.level, 0, 1) * 0.18)

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 24
            blur: root.active ? 0.08 : 0.02
        }
    }

    Repeater {
        model: 42

        Rectangle {
            readonly property real seedA: root.random(index, 1.7)
            readonly property real seedB: root.random(index, 4.1)
            readonly property real seedC: root.random(index, 8.3)
            readonly property real intensity: root.clamp(root.level, 0, 1)
            readonly property real wave: Math.sin(root.tick * (0.9 + seedA * 2.2) + index * 0.48)
            readonly property real drift: Math.cos(root.tick * (0.6 + seedC) + index * 0.31)

            width: 3 + seedA * 4 + intensity * 7
            height: width
            radius: width / 2
            x: 8 + seedB * Math.max(1, root.width - 16) + drift * intensity * 8
            y: root.height / 2 - height / 2 + wave * (4 + intensity * 18) + (seedC - 0.5) * 10
            color: Qt.rgba(
                Theme.info.r + (1 - Theme.info.r) * seedA * 0.18,
                Theme.info.g + (1 - Theme.info.g) * seedB * 0.18,
                Theme.info.b + (1 - Theme.info.b) * 0.35,
                0.18 + seedA * 0.30 + intensity * 0.45
            )
            scale: 0.55 + seedC * 0.55 + intensity * 0.65 + Math.max(0, wave) * intensity * 0.35

            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
    }
}
