import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root

    function trigger() {
        heartBurst.stop()
        heartState.burstProgress = 0.0
        heartState.glow = 0.0
        heartState.glowSweep = 0.0
        heartState.rayChaos = 0.0
        heartBurst.start()
    }

    QtObject {
        id: heartState

        property real burstProgress: 0.0
        property real glow: 0.0
        property real glowSweep: 0.0
        property real rayChaos: 0.0
        property int seed: 0

        function heartRandom(index, salt) {
            const value = Math.sin((index + 1) * (salt + 12.9898) + (heartState.seed * 0.137)) * 43758.5453
            return value - Math.floor(value)
        }
    }

    SequentialAnimation {
        id: heartBurst
        running: false
        ScriptAction { script: heartState.seed = Math.floor(Math.random() * 100000) }
        PropertyAction { target: heartState; property: "burstProgress"; value: 0.0 }
        PropertyAction { target: heartState; property: "glow"; value: 0.0 }
        PropertyAction { target: heartState; property: "glowSweep"; value: 0.0 }
        PropertyAction { target: heartState; property: "rayChaos"; value: 0.0 }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: heartState
                    property: "glow"
                    from: 0.0
                    to: 1.0
                    duration: AnimationConfig.durationVerySlow + AnimationConfig.durationSlow
                    easing.type: AnimationConfig.easingSmoothOut
                }
                PauseAnimation { duration: AnimationConfig.durationVerySlow + AnimationConfig.durationSlow }
                NumberAnimation {
                    target: heartState
                    property: "glow"
                    to: 0.0
                    duration: AnimationConfig.durationVerySlow
                    easing.type: AnimationConfig.easingDefaultOut
                }
            }
            NumberAnimation {
                target: heartState
                property: "burstProgress"
                from: 0.0
                to: 1.0
                duration: (AnimationConfig.durationExtraSlow + AnimationConfig.durationVerySlow) * 3
                easing.type: AnimationConfig.easingDefaultInOut
            }
            NumberAnimation {
                target: heartState
                property: "glowSweep"
                from: 0.0
                to: 1.0
                duration: (AnimationConfig.durationExtraSlow + AnimationConfig.durationVerySlow) * 3
                easing.type: AnimationConfig.easingDefaultInOut
            }
            NumberAnimation {
                target: heartState
                property: "rayChaos"
                from: 0.0
                to: 1.0
                duration: (AnimationConfig.durationExtraSlow + AnimationConfig.durationVerySlow) * 7.5
                easing.type: AnimationConfig.easingDefaultInOut
            }
        }
        PropertyAction { target: heartState; property: "burstProgress"; value: 0.0 }
        PropertyAction { target: heartState; property: "glow"; value: 0.0 }
        PropertyAction { target: heartState; property: "glowSweep"; value: 0.0 }
        PropertyAction { target: heartState; property: "rayChaos"; value: 0.0 }
    }

    Rectangle {
        id: backGlowLayer
        parent: root.parent && root.parent.parent ? root.parent.parent : root
        width: Math.max((root.width > 0 ? root.width : root.implicitWidth) + 12, 140)
        height: Math.max((root.height > 0 ? root.height : root.implicitHeight) + 10, 70)
        x: root.parent && root.parent.parent ? root.parent.x + root.x + (((root.width > 0 ? root.width : root.implicitWidth) - width) / 2) : (((root.width > 0 ? root.width : root.implicitWidth) - width) / 2)
        y: root.parent && root.parent.parent ? root.parent.y + root.y + (((root.height > 0 ? root.height : root.implicitHeight) - height) / 2) : (((root.height > 0 ? root.height : root.implicitHeight) - height) / 2)
        z: root.parent && root.parent.parent ? root.parent.z - 0.5 : -0.5
        radius: root.parent && root.parent.radius ? root.parent.radius + 14 : height / 2
        visible: root.visible && heartState.glow > 0.0
        opacity: heartState.glow * 0.72
        color: Qt.rgba(1.0, 0.22, 0.62, 0.26)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: AnimationConfig.blurMaxNormal
            blur: 1.0
            shadowEnabled: true
            shadowColor: Qt.rgba(1.0, 0.18, 0.58, 0.82)
            shadowBlur: 1.0
            shadowScale: 1.18
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    Item {
        id: sunRaysLayer
        parent: root.parent && root.parent.parent ? root.parent.parent : root
        width: Math.max((root.width > 0 ? root.width : root.implicitWidth) + 160, 420)
        height: Math.max((root.height > 0 ? root.height : root.implicitHeight) + 150, 220)
        x: root.parent && root.parent.parent ? root.parent.x + root.x + (((root.width > 0 ? root.width : root.implicitWidth) - width) / 2) : (((root.width > 0 ? root.width : root.implicitWidth) - width) / 2)
        y: root.parent && root.parent.parent ? root.parent.y + root.y + (((root.height > 0 ? root.height : root.implicitHeight) - height) / 2) : (((root.height > 0 ? root.height : root.implicitHeight) - height) / 2)
        z: root.parent && root.parent.parent ? root.parent.z - 1 : -1
        visible: root.visible && heartState.glow > 0.0
        opacity: heartState.glow * 0.82

        Repeater {
            model: 15

            Rectangle {
                readonly property real raySeed: heartState.heartRandom(index, 23.7)
                readonly property real rayPhase: heartState.rayChaos * Math.PI * (4.5 + heartState.heartRandom(index, 28.4) * 4.0) + heartState.heartRandom(index, 29.6) * Math.PI * 2.0
                readonly property real rayFlicker: 0.55 + (Math.sin(rayPhase) * 0.22) + (Math.cos(rayPhase * 1.73) * 0.16) + (heartState.heartRandom(index, 30.8) * 0.18)
                readonly property real rayDrift: Math.sin(rayPhase * 0.83) * (4 + heartState.heartRandom(index, 31.2) * 10)
                readonly property real rayLift: Math.cos(rayPhase * 1.17) * (3 + heartState.heartRandom(index, 32.6) * 9)
                width: 2 + heartState.heartRandom(index, 24.1) * 3
                height: 34 + heartState.heartRandom(index, 25.3) * 44
                radius: width / 2
                x: (sunRaysLayer.width / 2) - (width / 2) + rayDrift
                y: (sunRaysLayer.height / 2) - height + 4 + rayLift
                rotation: -112 + (index * 224 / 14) + ((raySeed - 0.5) * 12) + (Math.sin(rayPhase * 1.31) * (4 + heartState.heartRandom(index, 33.1) * 9))
                transformOrigin: Item.Bottom
                color: Qt.rgba(1.0, Math.min(1.0, 0.72 + (heartState.heartRandom(index, 26.5) * 0.2) + (rayFlicker * 0.08)), Math.min(1.0, 0.42 + (heartState.heartRandom(index, 27.9) * 0.18) + (rayFlicker * 0.1)), 0.18 + Math.max(0.0, Math.min(1.0, rayFlicker)) * 0.28)
                opacity: Math.max(0.18, Math.min(1.0, rayFlicker))
                scale: 0.82 + (Math.max(0.0, Math.min(1.0, rayFlicker)) * 0.36)
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxLight
                    blur: 0.62
                    shadowEnabled: true
                    shadowColor: Qt.rgba(1.0, 0.45, 0.72, 0.72)
                    shadowBlur: 1.0
                    shadowScale: 1.38
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }

    Item {
        id: islandInnerGlow
        anchors.fill: parent
        z: 0
        clip: true
        visible: heartState.glow > 0.0
        opacity: heartState.glow * 0.16
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: islandInnerGlowMask
        }

        Rectangle {
            id: islandInnerGlowMask
            anchors.fill: parent
            radius: root.parent && root.parent.radius ? root.parent.radius : 0
            color: "#ffffff"
            visible: false
            layer.enabled: true
        }

        Rectangle {
            width: Math.max(parent.width * 0.5, 120)
            height: parent.height
            radius: height / 2
            x: -width + ((parent.width + width) * heartState.glowSweep)
            y: 0
            color: Qt.rgba(1.0, 0.28, 0.68, 0.62)
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: AnimationConfig.blurMaxNormal
                blur: 3.0
                shadowEnabled: true
                shadowColor: Qt.rgba(1.0, 0.28, 0.62, 0.0)
                shadowBlur: 1.0
                shadowScale: 1.0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    Item {
        id: heartLayer
        anchors.centerIn: parent
        width: Math.max((root.width > 0 ? root.width : root.implicitWidth) + 120, 360)
        height: Math.max((root.height > 0 ? root.height : root.implicitHeight) + 120, 190)
        z: 0
        visible: heartState.burstProgress > 0.0

        Repeater {
            model: 18

            Text {
                id: heartGlyph
                readonly property real delay: heartState.heartRandom(index, 1.3) * 0.18
                readonly property real progress: Math.max(0.0, Math.min(1.0, (heartState.burstProgress - delay) / (0.78 + (heartState.heartRandom(index, 2.1) * 0.18))))
                readonly property real floatWave: Math.sin((progress * Math.PI * (1.7 + heartState.heartRandom(index, 3.2))) + (heartState.heartRandom(index, 4.4) * 6.28))
                readonly property real driftWave: Math.cos((progress * Math.PI * (1.2 + heartState.heartRandom(index, 5.6))) + (heartState.heartRandom(index, 6.8) * 6.28))
                readonly property real baseX: heartLayer.width * (0.08 + (heartState.heartRandom(index, 7.2) * 0.84))
                readonly property real baseY: heartLayer.height * (0.18 + (heartState.heartRandom(index, 8.6) * 0.64))
                text: heartState.heartRandom(index, 9.1) > 0.35 ? "❤" : "♡"
                color: heartState.heartRandom(index, 10.5) > 0.5 ? "#ff4f9a" : "#ffd1e3"
                font.pixelSize: 12 + Math.floor(heartState.heartRandom(index, 11.4) * 11)
                font.bold: true
                renderType: Text.NativeRendering
                opacity: Math.max(0.0, Math.sin(progress * Math.PI)) * (0.6 + (heartState.heartRandom(index, 12.7) * 0.4))
                scale: 0.68 + (Math.sin(progress * Math.PI) * (0.2 + heartState.heartRandom(index, 13.9) * 0.26))
                x: baseX - (width / 2) + (driftWave * (8 + (heartState.heartRandom(index, 14.2) * 30)))
                y: baseY - (height / 2) + (floatWave * (8 + (heartState.heartRandom(index, 15.8) * 24))) - (progress * (5 + (heartState.heartRandom(index, 16.1) * 16)))
                rotation: -18 + (heartState.heartRandom(index, 17.3) * 36) + (driftWave * 10)
                visible: opacity > 0.01
                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(1.0, 0.22, 0.62, 1.0)
                    shadowBlur: 1.0
                    shadowScale: 1.65
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }
}
