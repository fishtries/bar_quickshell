import QtQuick
import "../../core"
import "../../modules/volume"
import "../../modules/aside"
import "../../modules/controlcenter"
import ".."

Row {
    id: rightGroup
    spacing: 12

    property alias volModule: volModule
    property alias asideModule: asideModule
    property alias ccModule: ccModule

    AnimatedBarItem {
        anchors.verticalCenter: parent.verticalCenter
        triggerState: ccModule.isNotifIsland
        slideOffsetX: 60
        hiddenScale: 0.5
        enableBlur: false
        slideDuration: AnimationConfig.durationSlow
        opacityDuration: AnimationConfig.durationNormal
        scaleDuration: AnimationConfig.durationModerate
        scaleEasingType: AnimationConfig.easingSpringOut

        VolumeModule {
            id: volModule
        }
    }

    AsideModule {
        id: asideModule
        anchors.verticalCenter: parent.verticalCenter
    }

    // Control Center
    Item {
        width: ccModule.implicitWidth
        height: ccModule.implicitHeight
        ControlCenterModule {
            id: ccModule
        }
    }
}
