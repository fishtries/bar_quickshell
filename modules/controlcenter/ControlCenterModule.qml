import QtQuick
import Quickshell
import QtQuick.Effects
import Quickshell.Services.Notifications
import "../../core"

Rectangle {
    id: root

    // ─── Notification Island Morphing ──────────────────────────────────
    property bool isNotifIsland: false
    property var currentNotification: null  // latest notification for the island
    readonly property bool notifExpanded: islandView.notifExpanded

    color: isNotifIsland ? "#000000" : Theme.bgPanel
    radius: isNotifIsland ? (notifExpanded ? AnimationConfig.radiusCCNotifExpanded : AnimationConfig.radiusCCNotifCompact) : Theme.radiusPanel

    readonly property int compactIslandHeight: 64
    readonly property int expandedIslandHeight: 120

    implicitWidth: isNotifIsland ? (notifExpanded ? 420 : 280) : (networkIcons.width + 12)
    implicitHeight: isNotifIsland ? (notifExpanded ? expandedIslandHeight : compactIslandHeight) : (networkIcons.height + 4)

    // Blur spike on island transition
    property real animBlur: 0.0
    onIsNotifIslandChanged: blurPulse.restart()

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: AnimationConfig.durationFast; easing.type: AnimationConfig.easingSmoothOut }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: AnimationConfig.durationNormal; easing.type: AnimationConfig.easingDefaultOut }
    }

    // Smooth Transitions
    Behavior on color { ColorAnimation { duration: AnimationConfig.durationModerate } }
    Behavior on radius { NumberAnimation { duration: AnimationConfig.durationMedium; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudeDefault; easing.period: AnimationConfig.springPeriodCCRadius } }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: AnimationConfig.durationVerySlow
            easing.type: AnimationConfig.easingSpringOut
            easing.amplitude: AnimationConfig.springAmplitudeCC; easing.period: AnimationConfig.springPeriodCC
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: AnimationConfig.durationSlow
            easing.type: AnimationConfig.easingSpringOut
            easing.amplitude: AnimationConfig.springAmplitudeCC; easing.period: AnimationConfig.springPeriodCC
        }
    }

    // Secondary Effects (Blur)
    layer.enabled: animBlur > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: AnimationConfig.blurMaxNormal
        blur: root.animBlur
    }

    // ─── Notification tracking ─────────────────────────────────────────
    // Island shows the LATEST notification only.
    // Remaining notifications are shown as cards below the island (in bar.qml).
    // Presented tracking is centralized in NotificationState singleton.

    ListView {
        id: notifTracker
        visible: false
        width: 0; height: 0
        model: NotificationState.activeNotifications
        delegate: Item {}
        onCountChanged: {
            if (count === 0) {
                root.currentNotification = null
                islandView.stopAutoHide()
                root.isNotifIsland = false
            }
        }
    }

    Connections {
        target: NotificationState
        function onNewNotification(notification) {
            // If popout is open, don't show island — notification goes straight to the list
            if (root.popoutOpen) {
                return
            }
            root.currentNotification = notification
            islandView.resetInteraction()
            root.isNotifIsland = true
            islandView.restartAutoHide()
            // New notification is implicitly un-presented; will be marked when auto-hide fires
        }
    }

    property bool popoutOpen: false
    property Item popoutItem: popout

    onPopoutOpenChanged: {
        if (popoutOpen) {
            // Hide island when popout opens — notifications go to the list
            root.isNotifIsland = false
            islandView.collapse()
            islandView.stopAutoHide()
        } else {
            // When popout closes, don't re-show island for already-seen notifications.
            // The island will activate again only when a NEW notification arrives (onNewNotification).
            root.currentNotification = null
        }
    }

    // ─── Данные Math Mode ───────────────────────────────────────────
    property bool mathActive: false

    NetworkIconsGroup {
        id: networkIcons
        anchors.centerIn: parent
        isNotifIsland: root.isNotifIsland
        onPopoutToggleRequested: root.popoutOpen = !root.popoutOpen
    }

    IslandNotificationView {
        id: islandView
        anchors.fill: parent
        isNotifIsland: root.isNotifIsland
        currentNotification: root.currentNotification
        dismissThreshold: root.dismissThreshold

        onDismissRequested: root.dismissNotification()
        onAutoHideDismissRequested: root.dismissNotificationFromAutoHide()
        onHideRequested: {
            // Mark current as presented, then find next un-presented notification
            NotificationState.markPresented(root.currentNotification)
            var next = NotificationState.findNextUnpresented(root.currentNotification)

            if (next) {
                root.currentNotification = next
                islandView.resetInteraction()
                islandView.restartAutoHide()
            } else {
                root.currentNotification = null
                root.isNotifIsland = false
                islandView.stopAutoHide()
            }
            islandView.collapse()
            islandView.resetSwipe()
        }
    }

    // ─── Drag-to-dismiss + Hover MouseArea ──────────────────────────────
    readonly property real dismissThreshold: 100
    readonly property bool isDragging: islandView.isDragging

    function dismissNotification() {
        var dismissed = root.currentNotification
        if (dismissed)
            dismissed.dismiss()

        // Find next un-presented notification
        var next = NotificationState.findNextUnpresented(dismissed)

        if (next) {
            root.currentNotification = next
            islandView.resetInteraction()
            islandView.restartAutoHide()
        } else {
            root.currentNotification = null
            root.isNotifIsland = false
            islandView.stopAutoHide()
        }
        islandView.collapse()
        islandView.resetSwipe()
    }

    function dismissNotificationFromAutoHide() {
        var dismissed = root.currentNotification
        if (dismissed)
            dismissed.dismiss()

        // Find next un-presented notification
        var next = NotificationState.findNextUnpresented(dismissed)

        if (next) {
            root.currentNotification = next
            islandView.resetInteraction()
            islandView.restartAutoHide()
        } else {
            root.currentNotification = null
            root.isNotifIsland = false
            islandView.stopAutoHide()
        }

        islandView.collapse()
        islandView.resetSwipe()
    }

    // Apply drag offset + visual feedback to the island content
    transform: [
        Translate {
            y: root.isNotifIsland ? (root.notifExpanded ? 48 : 18) : 0
            Behavior on y { NumberAnimation { duration: AnimationConfig.durationDragSnap; easing.type: AnimationConfig.easingDefaultOut } }
        },
        Translate {
            x: islandView.visualOffsetX
            y: islandView.visualOffsetY
            Behavior on x { NumberAnimation { duration: AnimationConfig.durationMedium; easing.type: AnimationConfig.easingOvershootOut; easing.overshoot: AnimationConfig.dragOvershoot } }
            Behavior on y { NumberAnimation { duration: AnimationConfig.durationMedium; easing.type: AnimationConfig.easingOvershootOut; easing.overshoot: AnimationConfig.dragOvershoot } }
        }
    ]

    // Fade out as drag distance increases, smoothly return to 1.0
    opacity: islandView.dragOpacity
    Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

    // ─── Попаут ─────────────────────────────────────────────────────────

    ControlCenterPopout {
        id: popout
        isOpen: root.popoutOpen

        wifiConnected: NetworkState.wifiConnected
        wifiEssid: NetworkState.wifiEssid
        btStatus: networkIcons.displayBtStatus

        onCloseRequested: root.popoutOpen = false
        onRequestMathDetails: MathState.popoutOpen = true

        anchors.top: networkIcons.bottom
        anchors.topMargin: 6
        anchors.right: networkIcons.right

        // Анимация открывается из центра между иконками Wi-Fi и Bluetooth
        originX: popout.popoutWidth - (networkIcons.width / 2)
    }
}
