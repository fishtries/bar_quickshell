import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../core"
import "../../components"

PanelWindow {
    id: root

    signal requestControlCenter()

    IslandController {
        id: controller
        onRequestControlCenter: root.requestControlCenter()
    }

    readonly property bool hasNotification: controller.hasNotification
    readonly property bool expanded: controller.isExpanded
    readonly property string visualState: controller.visualState
    readonly property int topOffset: 8
    readonly property int compactWidth: 160
    readonly property int compactHeight: 36
    readonly property int expandedWidth: 360
    readonly property int compactRadius: AnimationConfig.radiusIslandCompact
    readonly property int expandedRadius: AnimationConfig.radiusIslandExpanded
    readonly property int horizontalPadding: 14
    readonly property int verticalPadding: 10
    readonly property int detailSpacing: 8
    readonly property string iconText: controller.iconText
    readonly property string appLabel: controller.appLabel
    readonly property string summaryLabel: controller.summaryLabel
    readonly property string bodyLabel: controller.bodyLabel
    readonly property real expandedBubbleHeight: Math.max(90, headerRow.implicitHeight + detailColumn.implicitHeight + detailSpacing + (verticalPadding * 2))
    readonly property real targetBubbleWidth: visualState === "hidden" ? 0 : visualState === "expanded" ? expandedWidth : compactWidth
    readonly property real targetBubbleHeight: visualState === "hidden" ? 0 : visualState === "expanded" ? expandedBubbleHeight : compactHeight
    readonly property real targetBubbleRadius: visualState === "hidden" ? 0 : visualState === "expanded" ? expandedRadius : compactRadius

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
            opacity: root.visualState === "hidden" ? 0 : 1
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
                enabled: root.hasNotification
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

            Item {
                anchors.fill: parent

                RowLayout {
                    id: headerRow
                    x: root.horizontalPadding
                    y: root.expanded ? root.verticalPadding : Math.max(0, (bubble.height - implicitHeight) / 2)
                    width: Math.max(0, parent.width - (root.horizontalPadding * 2))
                    spacing: 10

                    AppIcon {
                        text: root.iconText
                        font.pixelSize: root.expanded ? 18 : 16
                        color: Theme.info
                        Layout.alignment: Qt.AlignVCenter
                    }

                    AppText {
                        text: root.appLabel
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        font.pixelSize: root.expanded ? 14 : 13
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Item {
                    id: detailWrapper
                    x: root.horizontalPadding
                    y: headerRow.y + headerRow.height + root.detailSpacing
                    width: Math.max(0, parent.width - (root.horizontalPadding * 2))
                    height: root.expanded ? detailColumn.implicitHeight : 0
                    opacity: root.expanded ? 1 : 0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: AnimationConfig.durationIslandFade
                            easing.type: AnimationConfig.easingDefaultOut
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: AnimationConfig.durationQuick
                            easing.type: AnimationConfig.easingDefaultOut
                        }
                    }

                    Column {
                        id: detailColumn
                        width: parent.width
                        spacing: 4

                        AppText {
                            width: parent.width
                            text: root.summaryLabel
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        AppText {
                            id: bodyText
                            width: parent.width
                            text: root.bodyLabel
                            visible: text !== ""
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
