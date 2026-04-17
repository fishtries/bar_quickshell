import QtQuick
import QtQuick.Effects
import "../core"

Item {
    id: root

    default property alias content: contentHost.data

    property bool triggerState: false
    property real slideOffsetX: 0

    property real hiddenScale: 0.1
    property bool enableBlur: true

    property int slideDuration: AnimationConfig.durationVerySlow
    property int slideEasingType: AnimationConfig.easingMovement

    property int opacityDuration: AnimationConfig.durationFast

    property int scaleDuration: AnimationConfig.durationMedium
    property int scaleEasingType: AnimationConfig.easingSpring
    property real scaleEasingPeriod: AnimationConfig.springPeriodDefault

    property int blurDuration: AnimationConfig.durationModerate
    property real blurMax: AnimationConfig.blurMaxNormal

    readonly property Item firstContentChild: contentHost.children.length > 0 ? contentHost.children[0] : null

    implicitWidth: firstContentChild ? Math.max(contentHost.childrenRect.width, firstContentChild.implicitWidth) : 0
    implicitHeight: firstContentChild ? Math.max(contentHost.childrenRect.height, firstContentChild.implicitHeight) : 0
    width: implicitWidth
    height: implicitHeight

    opacity: triggerState ? 0 : 1
    scale: triggerState ? hiddenScale : 1.0

    Behavior on opacity {
        NumberAnimation {
            duration: root.opacityDuration
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.scaleDuration
            easing.type: root.scaleEasingType
            easing.period: root.scaleEasingPeriod
        }
    }

    transform: Translate {
        x: root.triggerState ? root.slideOffsetX : 0
        Behavior on x {
            NumberAnimation {
                duration: root.slideDuration
                easing.type: root.slideEasingType
            }
        }
    }

    layer.enabled: root.enableBlur && root.triggerState
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: root.blurMax
        blur: root.triggerState ? 1.0 : 0.0
        Behavior on blur {
            NumberAnimation {
                duration: root.blurDuration
            }
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
