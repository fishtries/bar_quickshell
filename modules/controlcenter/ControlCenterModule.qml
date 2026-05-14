import QtQuick
import Quickshell
import QtQuick.Effects
import Quickshell.Services.Notifications
import "../../core"
import "../../components"

Rectangle {
    id: root

    // ─── Notification Island Morphing ──────────────────────────────────
    property bool isNotifIsland: false
    property var currentNotification: null  // latest notification for the island
    readonly property bool notifExpanded: islandView.notifExpanded
    readonly property bool notifReplyVisible: islandView.replyVisible

    color: isNotifIsland ? "#000000" : Theme.localPanelForItem(root)
    radius: isNotifIsland ? (notifExpanded ? AnimationConfig.radiusCCNotifExpanded : AnimationConfig.radiusCCNotifCompact) : Theme.radiusPanel

    readonly property int compactIslandHeight: 64
    readonly property int expandedIslandHeight: notifReplyVisible ? 140 : 108

    implicitWidth: isNotifIsland ? (notifExpanded ? (notifReplyVisible ? 400 : 390) : 280) : (networkIcons.width + 12)
    implicitHeight: isNotifIsland ? (notifExpanded ? expandedIslandHeight : compactIslandHeight) : (networkIcons.height + 4)
    x: islandView.visualOffsetX
    y: (isNotifIsland ? (notifExpanded ? 38 : 18) : 0) + islandView.visualOffsetY

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
    Behavior on x { NumberAnimation { duration: AnimationConfig.durationMedium; easing.type: AnimationConfig.easingOvershootOut; easing.overshoot: AnimationConfig.dragOvershoot } }
    Behavior on y { NumberAnimation { duration: AnimationConfig.durationMedium; easing.type: AnimationConfig.easingOvershootOut; easing.overshoot: AnimationConfig.dragOvershoot } }

    // Secondary Effects (Blur)
    layer.enabled: animBlur > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: AnimationConfig.blurMaxNormal
        blur: root.animBlur
        shadowEnabled: false
        shadowColor: Qt.rgba(1.0, 0.28, 0.62, 0.0)
        shadowBlur: 0.0
        shadowScale: 1.0
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    // ─── Notification tracking ─────────────────────────────────────────
    // Queue-based notification display: unseen notifications are shown one-by-one
    // in the island. After auto-hide or dismiss, the next unseen is shown.
    // Already-seen notifications remain in Control Center but don't reappear in island.

    property var unseenQueue: []

    function tryDismissNotification(notification) {
        if (!notification)
            return

        try {
            if (typeof notification.dismiss === "function")
                notification.dismiss()
        } catch (e) {
        }
    }

    function showNotificationInIsland(notification) {
        if (!notification)
            return

        NotificationState.notificationUid(notification)
        root.currentNotification = notification
        root.isNotifIsland = true
        NotificationState.notifyIslandNotificationShown(notification)
        islandView.resetInteraction()
        islandView.collapse()
        islandView.resetSwipe()
        islandView.restartAutoHide()
    }

    function showNextUnseen() {
        var nextNotification = NotificationState.takeNextStackNotification()
        if (nextNotification) {
            showNotificationInIsland(nextNotification)
            return
        }

        root.currentNotification = null
        root.isNotifIsland = false
        islandView.collapse()
        islandView.stopAutoHide()
    }

    ListView {
        id: notifTracker
        visible: false
        width: 0; height: 0
        model: NotificationState.activeNotifications
        delegate: Item {}
        onCountChanged: {
            NotificationState.syncNotificationRefs()
            if (count === 0) {
                root.currentNotification = null
                islandView.stopAutoHide()
                root.isNotifIsland = false
                root.unseenQueue = []
                NotificationState.clearStackNotifications()
            } else if (root.currentNotification) {
                var items = NotificationState.activeNotifications.values
                if (items && items.indexOf(root.currentNotification) === -1) {
                    showNextUnseen()
                }
            }
        }
    }

    Connections {
        target: NotificationState
        function onNewNotification(notification) {
            // If popout is open, don't show island — notification goes straight to the list
            if (root.popoutOpen) return
            if (NotificationState.doNotDisturb) return

            NotificationState.notificationUid(notification)

            if (!root.isNotifIsland || !root.currentNotification)
                showNotificationInIsland(notification)
            else
                NotificationState.pushStackNotification(notification)
        }
    }

    property bool popoutOpen: false
    property Item popoutItem: popout
    property real popoutTopY: 0

    onPopoutOpenChanged: {
        if (popoutOpen) {
            // Hide island when popout opens — notifications go to the list
            root.isNotifIsland = false
            islandView.collapse()
            islandView.stopAutoHide()
            root.unseenQueue = []
            NotificationState.clearStackNotifications()
        } else {
            // When popout closes, don't re-show island for already-seen notifications.
            // The island will activate again only when a NEW notification arrives.
            root.currentNotification = null
        }
    }

    HeartBurstOverlay {
        id: heartEffect
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        z: 0
        visible: root.visible && root.isNotifIsland
    }

    Connections {
        target: NotificationState
        function onSpecialTelegramMessageReceived() {
            heartEffect.trigger()
        }
    }

    // ─── Данные Math Mode ───────────────────────────────────────────
    property bool mathActive: false

    NetworkIconsGroup {
        id: networkIcons
        anchors.centerIn: parent
        z: 1
        isNotifIsland: root.isNotifIsland
        onPopoutToggleRequested: root.popoutOpen = !root.popoutOpen
    }

    IslandNotificationView {
        id: islandView
        anchors.fill: parent
        z: 2
        isNotifIsland: root.isNotifIsland
        currentNotification: root.currentNotification
        dismissThreshold: root.dismissThreshold

        onDismissRequested: root.dismissNotification()
        onAutoHideDismissRequested: root.dismissNotificationFromAutoHide()
        onHideRequested: {
            var hiddenNotification = root.currentNotification
            NotificationState.markPresented(hiddenNotification)
            islandView.collapse()
            islandView.resetSwipe()
            
            var nextNotification = NotificationState.takeNextStackNotification()
            if (nextNotification) {
                showNotificationInIsland(nextNotification)
            } else {
                root.currentNotification = null
                root.isNotifIsland = false
                islandView.stopAutoHide()
            }
        }
    }

    // ─── Drag-to-dismiss + Hover MouseArea ──────────────────────────────
    readonly property real dismissThreshold: 100
    readonly property bool isDragging: islandView.isDragging

    function dismissNotification() {
        var dismissed = root.currentNotification
        
        islandView.collapse()
        islandView.resetSwipe()
        
        var nextNotification = NotificationState.takeNextStackNotification()
        if (nextNotification) {
            showNotificationInIsland(nextNotification)
        } else {
            root.currentNotification = null
            root.isNotifIsland = false
            islandView.stopAutoHide()
        }

        root.tryDismissNotification(dismissed)
    }

    function dismissNotificationFromAutoHide() {
        var dismissed = root.currentNotification
        
        islandView.collapse()
        islandView.resetSwipe()
        
        var nextNotification = NotificationState.takeNextStackNotification()
        if (nextNotification) {
            showNotificationInIsland(nextNotification)
        } else {
            root.currentNotification = null
            root.isNotifIsland = false
            islandView.stopAutoHide()
        }

        root.tryDismissNotification(dismissed)
    }

    // Fade out as drag distance increases, smoothly return to 1.0
    opacity: islandView.dragOpacity
    Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

    // ─── Попаут ─────────────────────────────────────────────────────────

    ControlCenterPopout {
        id: popout
        z: 3
        isOpen: root.popoutOpen

        wifiConnected: NetworkState.wifiConnected
        wifiEssid: NetworkState.wifiEssid
        btStatus: networkIcons.displayBtStatus

        onCloseRequested: root.popoutOpen = false
        onRequestMathDetails: MathState.popoutOpen = true

        anchors.top: networkIcons.bottom
        anchors.topMargin: 9
        anchors.right: networkIcons.right

        // Анимация открывается из центра между иконками Wi-Fi и Bluetooth
        originX: popout.popoutWidth - (networkIcons.width / 2)
    }
}
