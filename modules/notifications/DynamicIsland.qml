import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

PanelWindow {
    id: root

    signal requestControlCenter()

    IslandController {
        id: controller
        onRequestControlCenter: root.requestControlCenter()
    }

    readonly property int topOffset: 8
    readonly property int compactWidth: 160
    readonly property int compactHeight: 36
    readonly property int expandedWidth: 360
    readonly property int compactRadius: AnimationConfig.radiusIslandCompact
    readonly property int expandedRadius: AnimationConfig.radiusIslandExpanded
    property real contentProgress: controller.visualState === "expanded" ? 1 : 0
    readonly property real expandedBubbleHeight: notificationContent.implicitHeight
    readonly property real targetBubbleWidth: controller.visualState === "hidden" ? 0 : controller.visualState === "expanded" ? expandedWidth : compactWidth
    readonly property real targetBubbleHeight: controller.visualState === "hidden" ? 0 : controller.visualState === "expanded" ? expandedBubbleHeight : compactHeight
    readonly property real targetBubbleRadius: controller.visualState === "hidden" ? 0 : controller.visualState === "expanded" ? expandedRadius : compactRadius

    Behavior on contentProgress {
        NumberAnimation {
            duration: AnimationConfig.durationIslandFade
            easing.type: AnimationConfig.easingDefaultOut
        }
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "qs-dynamic-island"
    implicitHeight: bubble.height > 0 ? bubble.height + topOffset : 0

    mask: Region {
        item: bubbleWrapper
    }

    Item {
        id: bubbleWrapper
        anchors.top: parent.top
        anchors.topMargin: root.topOffset
        anchors.horizontalCenter: parent.horizontalCenter
        width: bubble.width
        height: bubble.height

        Rectangle {
            id: bubble
            anchors.centerIn: parent
            width: root.targetBubbleWidth
            height: root.targetBubbleHeight
            radius: root.targetBubbleRadius
            opacity: controller.visualState === "hidden" ? 0 : 1
            color: Theme.bgPopout
            border.color: Qt.rgba(1, 1, 1, interactionArea.containsMouse ? 0.16 : 0.08)
            border.width: width > 0 ? 1 : 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: AnimationConfig.durationIslandSpring
                    easing.type: AnimationConfig.easingSpringOut
                    easing.period: AnimationConfig.springPeriodIsland
                    easing.amplitude: AnimationConfig.springAmplitudeIsland
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: AnimationConfig.durationIslandSpring
                    easing.type: AnimationConfig.easingSpringOut
                    easing.period: AnimationConfig.springPeriodIsland
                    easing.amplitude: AnimationConfig.springAmplitudeIsland
                }
            }

            Behavior on radius {
                NumberAnimation {
                    duration: AnimationConfig.durationIslandSpring
                    easing.type: AnimationConfig.easingSpringOut
                    easing.period: AnimationConfig.springPeriodIsland
                    easing.amplitude: AnimationConfig.springAmplitudeIsland
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: AnimationConfig.durationIslandFade
                    easing.type: AnimationConfig.easingDefaultOut
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: AnimationConfig.durationQuick
                }
            }

            MouseArea {
                id: interactionArea
                anchors.fill: parent
                enabled: controller.hasNotification
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                onEntered: {
                    controller.handleHover(true);
                }

                onExited: {
                    controller.handleHover(false);
                }

                onClicked: {
                    controller.handleClick();
                }
            }

            IslandContent {
                id: notificationContent
                anchors.fill: parent
                iconSource: controller.iconText
                appName: controller.appLabel
                summary: controller.summaryLabel
                body: controller.bodyLabel
                progress: root.contentProgress
            }
        }
    }
}
