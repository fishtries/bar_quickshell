import QtQuick
import QtQuick.Effects
import "../../core"

Item {
    id: root

    property real level: 0.0
    property bool active: false
    property real tick: 0.0

    implicitWidth: 176
    implicitHeight: 42
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

    Timer {
        interval: 16
        repeat: true
        running: root.active || root.level > 0.01
        onTriggered: root.tick += 0.02 + Math.min(root.level, 1.0) * 0.08
    }

    Rectangle {
        id: maskRect
        width: root.width
        height: root.height
        radius: height / 2
        color: "white"
        visible: false
    }

    // Masked container for the fluid effect
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskRect
        }

        // Dark background of the visualizer pill
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.05, 0.05, 0.05, 0.8)
        }

        // Aurora Blobs
        Repeater {
            model: [
                { c: "#2d82ff", x: 0.15, y: 0.5, s: 1.2, sp: 0.8 },
                { c: "#ff3a7c", x: 0.50, y: 0.6, s: 1.5, sp: 1.1 },
                { c: "#1cb5e0", x: 0.85, y: 0.4, s: 1.3, sp: 0.9 },
                { c: "#ff7e5f", x: 0.35, y: 0.5, s: 1.4, sp: 1.3 },
                { c: "#a124e4", x: 0.65, y: 0.5, s: 1.1, sp: 1.0 }
            ]
            
            Rectangle {
                property real waveX: Math.sin(root.tick * modelData.sp) * 30 * (1 + root.level * 1.5)
                property real waveY: Math.cos(root.tick * modelData.sp * 1.2) * 12 * (1 + root.level * 2.5)
                
                width: root.height * 2.2 * modelData.s * (1.0 + root.level * 0.6)
                height: root.height * 2.2 * modelData.s * (1.0 + root.level * 1.8)
                radius: width / 2
                
                x: root.width * modelData.x - width / 2 + waveX
                y: root.height * modelData.y - height / 2 + waveY
                
                color: modelData.c
                opacity: 0.7 + Math.min(root.level, 1.0) * 0.3
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                }
            }
        }
    }
    
    // Add an inner shadow/rim light for that glass pill look
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
    }
}
