import QtQuick
import "../../core"
import "../../modules/workspaces"
import "../../modules/math"
import "../../modules/audio"
import ".."

Row {
    id: centerGroup
    spacing: 20

    property alias wsModule: wsModule
    property alias mathModule: mathModule
    property alias audioVis: audioVis

    property Item popoutParent: null
    property real popoutTopY: 0

    AnimatedBarItem {
        anchors.verticalCenter: parent.verticalCenter
        triggerState: IslandState.isActive
        slideOffsetX: 100
        opacityDuration: AnimationConfig.durationModerate

        ActiveTitleModule {}
    }

    WorkspacesModule {
        id: wsModule
        interactionEnabled: !mathModule.isActive
    }

    AnimatedBarItem {
        anchors.verticalCenter: parent.verticalCenter
        triggerState: IslandState.isActive
        slideOffsetX: -100

        MathModule {
            id: mathModule
            popoutTopY: centerGroup.popoutTopY
        }
    }

    AnimatedBarItem {
        anchors.verticalCenter: parent.verticalCenter
        triggerState: IslandState.isActive
        slideOffsetX: -150

        CavaVisualizer {
            id: audioVis
            popoutParent: centerGroup.popoutParent
            popoutTopY: centerGroup.popoutTopY
        }
    }
}
