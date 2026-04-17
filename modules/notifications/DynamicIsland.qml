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

    property var currentNotification: null
    property int previousCount: 0
    property bool expanded: false

    readonly property bool hasNotification: currentNotification !== null

    // Store the latest notification directly from the signal
    // (UntypedObjectModel doesn't support .get())
    Connections {
        target: NotificationState
        function onNewNotification(notification) {
            root.currentNotification = notification;
            if (root.previousCount === 0) {
                root.previousCount = 1;
            }
            root.refreshCurrentNotification(true);
        }
    }
    readonly property string visualState: !hasNotification ? "hidden" : expanded ? "expanded" : "compact"
    readonly property int topOffset: 8
    readonly property int compactWidth: 160
    readonly property int compactHeight: 36
    readonly property int expandedWidth: 360
    readonly property int compactRadius: AnimationConfig.radiusIslandCompact
    readonly property int expandedRadius: AnimationConfig.radiusIslandExpanded
    readonly property int horizontalPadding: 14
    readonly property int verticalPadding: 10
    readonly property int detailSpacing: 8
    readonly property string appLabel: currentNotification && currentNotification.appName ? currentNotification.appName : "Notification"
    readonly property string summaryLabel: currentNotification && currentNotification.summary ? currentNotification.summary : appLabel
    readonly property string bodyLabel: currentNotification && currentNotification.body ? currentNotification.body : ""
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

    function restartAutoHide() {
        autoHideTimer.stop();
        if (hasNotification && !interactionArea.containsMouse) {
            autoHideTimer.start();
        }
    }

    function refreshCurrentNotification(isNewArrival) {
        if (!hasNotification) {
            expanded = false;
            expandTimer.stop();
            autoHideTimer.stop();
            return;
        }

        if (isNewArrival) {
            expanded = false;
        }

        if (interactionArea.containsMouse) {
            autoHideTimer.stop();
            if (!expanded) {
                expandTimer.restart();
            }
        } else {
            expandTimer.stop();
            restartAutoHide();
        }
    }

    ListView {
        id: notificationTracker
        visible: false
        width: 0
        height: 0
        model: NotificationState.activeNotifications
        delegate: Item {}

        onCountChanged: {
            const isNewArrival = count > root.previousCount;
            root.previousCount = count;
            if (count === 0) {
                root.currentNotification = null;
            }
            root.refreshCurrentNotification(isNewArrival);
        }
    }

    Component.onCompleted: {
        previousCount = notificationTracker.count;
        refreshCurrentNotification(false);
    }

    Timer {
        id: expandTimer
        interval: AnimationConfig.timerIslandExpand
        repeat: false
        onTriggered: {
            if (root.visualState === "compact") {
                root.expanded = true;
                expandTimer.stop();
            }
        }
    }

    Timer {
        id: autoHideTimer
        interval: AnimationConfig.timerIslandAutoHide
        repeat: false
        onTriggered: {
            if (root.currentNotification) {
                root.currentNotification.dismiss();
            }
        }
    }

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
                    autoHideTimer.stop();
                    if (!root.expanded && root.hasNotification) {
                        expandTimer.restart();
                    }
                }

                onExited: {
                    expandTimer.stop();
                    root.restartAutoHide();
                }

                onClicked: {
                    if (!root.currentNotification) {
                        return;
                    }

                    if (root.visualState === "compact") {
                        root.requestControlCenter();
                        root.currentNotification.dismiss();
                        return;
                    }

                    if (root.visualState === "expanded") {
                        root.currentNotification.invokeDefaultAction();
                        root.currentNotification.dismiss();
                    }
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
                        text: "\uf0f3"
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
