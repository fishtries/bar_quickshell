import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../core"
import "../../components"

Item {
    id: root

    property bool isNotifIsland: false
    property var currentNotification: null
    property real dismissThreshold: 100

    property bool notifExpanded: false
    property bool notifHovered: false
    property real hoverProgress: 0.0
    property bool notifInteracted: false

    property var displayedNotification: null
    property real notifBlur: 0.0

    readonly property bool isDragging: notifSwipe.isDragging
    readonly property real visualOffsetX: notifSwipe.visualOffsetX
    readonly property real visualOffsetY: notifSwipe.visualOffsetY
    readonly property real dragOpacity: notifSwipe.dragOpacity

    signal dismissRequested()
    signal autoHideDismissRequested()
    signal hideRequested()

    onIsDraggingChanged: {
        if (!isDragging && root.isNotifIsland && root.currentNotification && !islandMouseArea.containsMouse) {
            notifHovered = false
            hoverExpandTimer.stop()
            hoverProgress = 0.0
            notifExpanded = false
            restartAutoHide()
        }
    }

    function restartAutoHide() {
        notifAutoHide.restart()
    }

    function stopAutoHide() {
        notifAutoHide.stop()
    }

    function resetSwipe() {
        notifSwipe.reset()
    }

    function collapse() {
        notifExpanded = false
    }

    function resetInteraction() {
        notifInteracted = false
    }

    onCurrentNotificationChanged: {
        if (!currentNotification) {
            displayedNotification = null
            notifBlurPulse.stop()
            notifBlur = 0.0
        } else if (!displayedNotification) {
            displayedNotification = currentNotification
        } else if (displayedNotification !== currentNotification) {
            if (notifBlurPulse.running)
                notifBlurPulse.stop()
            notifBlurPulse.start()
        }
    }

    SequentialAnimation {
        id: notifBlurPulse
        NumberAnimation { target: root; property: "notifBlur"; to: 1.0; duration: AnimationConfig.durationVeryFast; easing.type: AnimationConfig.easingDefaultIn }
        ScriptAction { script: root.displayedNotification = root.currentNotification }
        NumberAnimation { target: root; property: "notifBlur"; to: 0.0; duration: AnimationConfig.durationDragSnap; easing.type: AnimationConfig.easingDefaultOut }
    }

    Timer {
        id: hoverExpandTimer
        interval: AnimationConfig.timerHoverTick
        repeat: true
        onTriggered: {
            if (root.notifHovered && root.isNotifIsland && !root.notifExpanded) {
                root.hoverProgress = Math.min(1.0, root.hoverProgress + AnimationConfig.timerHoverTick / 1000)
                if (root.hoverProgress >= 1.0) {
                    root.notifExpanded = true
                    stop()
                }
            }
        }
    }

    Timer {
        id: notifAutoHide
        interval: AnimationConfig.timerNotifAutoHide
        repeat: false
        onTriggered: {
            if (!root.notifInteracted) {
                root.hideRequested()
                return
            }
            root.autoHideDismissRequested()
        }
    }

    SwipeDismissible {
        id: notifSwipe
        anchors.fill: parent
        enabled: root.isNotifIsland
        visible: root.isNotifIsland
        dismissThreshold: root.dismissThreshold
        onDragStarted: root.notifInteracted = true
        onDismissed: root.dismissRequested()

        Item {
            id: notifIslandContent
            anchors.fill: parent
            opacity: root.isNotifIsland ? 1.0 : 0.0
            scale: root.isNotifIsland ? 1.0 : 0.6
            Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }
            Behavior on scale { NumberAnimation { duration: AnimationConfig.durationSlow; easing.type: AnimationConfig.easingOvershootOut } }

            RowLayout {
                id: compactView
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                opacity: root.notifExpanded ? 0.0 : 1.0
                scale: root.notifExpanded ? 0.8 : 1.0
                Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationFast } }
                Behavior on scale { NumberAnimation { duration: AnimationConfig.durationNormal; easing.type: AnimationConfig.easingOvershootOut } }

                AppIcon {
                    text: "\udb80\udd70"
                    font.pixelSize: 18
                    color: Theme.info
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: compactAppName.implicitHeight
                    layer.enabled: root.notifBlur > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: AnimationConfig.blurMaxLight
                        blur: root.notifBlur
                    }
                    AppText {
                        id: compactAppName
                        anchors.fill: parent
                        text: root.displayedNotification ? (root.displayedNotification.appName || "System") : ""
                        color: "#ffffff"
                        font { pixelSize: 14; weight: Font.DemiBold }
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 28
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)
                    visible: root.notifHovered && !root.notifExpanded

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * root.hoverProgress
                        radius: 2
                        color: Theme.info
                        Behavior on height { NumberAnimation { duration: AnimationConfig.durationHoverProgress } }
                    }
                }
            }

            RowLayout {
                id: expandedView
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                opacity: root.notifExpanded ? 1.0 : 0.0
                scale: root.notifExpanded ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationNormal; easing.type: AnimationConfig.easingDefaultOut } }
                Behavior on scale { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingOvershootOut } }

                AppIcon {
                    text: "\udb80\udd70"
                    font.pixelSize: 22
                    color: Theme.info
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: expandedTextCol.implicitHeight
                    layer.enabled: root.notifBlur > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: AnimationConfig.blurMaxLight
                        blur: root.notifBlur
                    }
                    ColumnLayout {
                        id: expandedTextCol
                        anchors.fill: parent
                        spacing: 2

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.appName || "System") : ""
                            color: "#ffffff"
                            font { pixelSize: 11; weight: Font.DemiBold }
                            opacity: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.summary || "") : ""
                            color: "#ffffff"
                            font { pixelSize: 15; weight: Font.Bold }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.body || "") : ""
                            color: "#cccccc"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            Layout.fillWidth: true
                            visible: text !== ""
                        }
                    }
                }
            }

            MouseArea {
                id: islandMouseArea
                anchors.fill: parent
                visible: root.isNotifIsland
                hoverEnabled: true
                z: 10

                onEntered: {
                    if (!root.isDragging) {
                        root.notifHovered = true
                        root.hoverProgress = 0.0
                        hoverExpandTimer.start()
                        root.stopAutoHide()
                    }
                }

                onExited: {
                    if (!root.isDragging) {
                        root.notifHovered = false
                        hoverExpandTimer.stop()
                        root.hoverProgress = 0.0
                        root.notifExpanded = false
                        root.restartAutoHide()
                    }
                }

                onClicked: function(mouse) {
                    if (!root.isDragging) {
                        root.notifInteracted = true
                        root.dismissRequested()
                    }
                }
            }
        }
    }
}
