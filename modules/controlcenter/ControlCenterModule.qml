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
    readonly property bool notifReplyVisible: islandView.replyVisible
    readonly property bool needsKeyboard: islandView.needsKeyboard
    readonly property string specialContactName: "Аделия Зайка"
    property real heartBurstProgress: 0.0
    property real heartGlow: 0.0
    property real heartGlowSweep: 0.0
    property int heartBurstSeed: 0

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
    layer.enabled: animBlur > 0 || heartGlow > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: AnimationConfig.blurMaxNormal
        blur: root.animBlur
        shadowEnabled: root.heartGlow > 0
        shadowColor: Qt.rgba(1.0, 0.28, 0.62, 0.85 * root.heartGlow)
        shadowBlur: root.heartGlow
        shadowScale: 1.0 + (root.heartGlow * 0.08)
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    // ─── Notification tracking ─────────────────────────────────────────
    // Queue-based notification display: unseen notifications are shown one-by-one
    // in the island. After auto-hide or dismiss, the next unseen is shown.
    // Already-seen notifications remain in Control Center but don't reappear in island.

    property var unseenQueue: []

    function matchesSpecialTelegramNotification(notification) {
        if (!notification)
            return false

        const target = root.specialContactName.toLowerCase()
        const appLabel = ((notification.appName || notification.desktopEntry || "") + "").toLowerCase()
        const summaryLabel = ((notification.summary || "") + "").toLowerCase()
        const bodyLabel = ((notification.body || "") + "").toLowerCase()
        const isTelegram = appLabel.indexOf("telegram") !== -1
        const bodyStartsWithName = bodyLabel === target || bodyLabel.indexOf(target + ":") === 0 || bodyLabel.indexOf(target + "\n") === 0

        return isTelegram && (summaryLabel.indexOf(target) !== -1 || bodyStartsWithName)
    }

    function triggerHeartBurst(notification) {
        if (!matchesSpecialTelegramNotification(notification)) {
            heartBurst.stop()
            root.heartBurstProgress = 0.0
            root.heartGlow = 0.0
            root.heartGlowSweep = 0.0
            return
        }

        heartBurst.stop()
        root.heartBurstProgress = 0.0
        root.heartGlow = 0.0
        root.heartGlowSweep = 0.0
        root.heartBurstSeed = Math.floor(Math.random() * 100000)
        heartBurst.start()
    }

    function heartRandom(index, salt) {
        const value = Math.sin((index + 1) * (salt + 12.9898) + (root.heartBurstSeed * 0.137)) * 43758.5453
        return value - Math.floor(value)
    }

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
        root.triggerHeartBurst(root.currentNotification)
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
                    root.currentNotification = null
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

            NotificationState.notificationUid(notification)

            if (!root.isNotifIsland || !root.currentNotification)
                showNotificationInIsland(notification)
            else
                NotificationState.pushStackNotification(notification)
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
            root.unseenQueue = []
            NotificationState.clearStackNotifications()
        } else {
            // When popout closes, don't re-show island for already-seen notifications.
            // The island will activate again only when a NEW notification arrives.
            root.currentNotification = null
        }
    }

    SequentialAnimation {
        id: heartBurst
        running: false
        PropertyAction { target: root; property: "heartBurstProgress"; value: 0.0 }
        PropertyAction { target: root; property: "heartGlow"; value: 0.0 }
        PropertyAction { target: root; property: "heartGlowSweep"; value: 0.0 }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "heartGlow"
                    from: 0.0
                    to: 1.0
                    duration: AnimationConfig.durationVerySlow + AnimationConfig.durationSlow
                    easing.type: AnimationConfig.easingSmoothOut
                }
                PauseAnimation { duration: AnimationConfig.durationVerySlow + AnimationConfig.durationSlow }
                NumberAnimation {
                    target: root
                    property: "heartGlow"
                    to: 0.0
                    duration: AnimationConfig.durationVerySlow
                    easing.type: AnimationConfig.easingDefaultOut
                }
            }
            NumberAnimation {
                target: root
                property: "heartBurstProgress"
                from: 0.0
                to: 1.0
                duration: (AnimationConfig.durationExtraSlow + AnimationConfig.durationVerySlow) * 3
                easing.type: AnimationConfig.easingDefaultInOut
            }
            NumberAnimation {
                target: root
                property: "heartGlowSweep"
                from: 0.0
                to: 1.0
                duration: (AnimationConfig.durationExtraSlow + AnimationConfig.durationVerySlow) * 3
                easing.type: AnimationConfig.easingDefaultInOut
            }
        }
        PropertyAction { target: root; property: "heartBurstProgress"; value: 0.0 }
        PropertyAction { target: root; property: "heartGlow"; value: 0.0 }
        PropertyAction { target: root; property: "heartGlowSweep"; value: 0.0 }
    }

    Item {
        id: sunRaysLayer
        parent: root.parent
        width: Math.max((root.width > 0 ? root.width : root.implicitWidth) + 160, 420)
        height: Math.max((root.height > 0 ? root.height : root.implicitHeight) + 150, 220)
        x: root.x + (((root.width > 0 ? root.width : root.implicitWidth) - width) / 2) + islandView.visualOffsetX
        y: root.y + (((root.height > 0 ? root.height : root.implicitHeight) - height) / 2) + (root.isNotifIsland ? (root.notifExpanded ? 48 : 18) : 0) + islandView.visualOffsetY
        z: root.z - 1
        visible: root.visible && root.isNotifIsland && root.heartGlow > 0.0
        opacity: root.heartGlow * 0.55

        Repeater {
            model: 15

            Rectangle {
                readonly property real raySeed: root.heartRandom(index, 23.7)
                width: 2 + root.heartRandom(index, 24.1) * 3
                height: 34 + root.heartRandom(index, 25.3) * 44
                radius: width / 2
                x: (sunRaysLayer.width / 2) - (width / 2)
                y: (sunRaysLayer.height / 2) - height + 4
                rotation: -112 + (index * 224 / 14) + ((raySeed - 0.5) * 12)
                transformOrigin: Item.Bottom
                color: Qt.rgba(1.0, 0.62 + (root.heartRandom(index, 26.5) * 0.18), 0.34 + (root.heartRandom(index, 27.9) * 0.16), 0.18)
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: AnimationConfig.blurMaxLight
                    blur: 0.62
                    shadowEnabled: true
                    shadowColor: Qt.rgba(1.0, 0.45, 0.72, 0.45)
                    shadowBlur: 0.8
                    shadowScale: 1.25
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
        visible: root.visible && root.isNotifIsland && root.heartGlow > 0.0
        opacity: root.heartGlow * 0.24

        Rectangle {
            width: Math.max(parent.width * 0.5, 120)
            height: parent.height * 1.75
            radius: height / 2
            x: -width + ((parent.width + width) * root.heartGlowSweep)
            y: (parent.height - height) / 2
            color: Qt.rgba(1.0, 0.24, 0.58, 0.36)
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: AnimationConfig.blurMaxNormal
                blur: 1.0
                shadowEnabled: true
                shadowColor: Qt.rgba(1.0, 0.28, 0.62, 0.4)
                shadowBlur: 0.55
                shadowScale: 1.18
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
        visible: root.visible && root.isNotifIsland && root.heartBurstProgress > 0.0

        Repeater {
            model: 18

            Text {
                id: heartGlyph
                readonly property real delay: root.heartRandom(index, 1.3) * 0.18
                readonly property real progress: Math.max(0.0, Math.min(1.0, (root.heartBurstProgress - delay) / (0.78 + (root.heartRandom(index, 2.1) * 0.18))))
                readonly property real floatWave: Math.sin((progress * Math.PI * (1.7 + root.heartRandom(index, 3.2))) + (root.heartRandom(index, 4.4) * 6.28))
                readonly property real driftWave: Math.cos((progress * Math.PI * (1.2 + root.heartRandom(index, 5.6))) + (root.heartRandom(index, 6.8) * 6.28))
                readonly property real baseX: heartLayer.width * (0.08 + (root.heartRandom(index, 7.2) * 0.84))
                readonly property real baseY: heartLayer.height * (0.18 + (root.heartRandom(index, 8.6) * 0.64))
                text: root.heartRandom(index, 9.1) > 0.35 ? "❤" : "♡"
                color: root.heartRandom(index, 10.5) > 0.5 ? "#ff7bb0" : "#ffb3d1"
                font.pixelSize: 12 + Math.floor(root.heartRandom(index, 11.4) * 11)
                font.bold: true
                renderType: Text.NativeRendering
                opacity: Math.max(0.0, Math.sin(progress * Math.PI)) * (0.35 + (root.heartRandom(index, 12.7) * 0.45))
                scale: 0.68 + (Math.sin(progress * Math.PI) * (0.2 + root.heartRandom(index, 13.9) * 0.26))
                x: baseX - (width / 2) + (driftWave * (8 + (root.heartRandom(index, 14.2) * 30)))
                y: baseY - (height / 2) + (floatWave * (8 + (root.heartRandom(index, 15.8) * 24))) - (progress * (5 + (root.heartRandom(index, 16.1) * 16)))
                rotation: -18 + (root.heartRandom(index, 17.3) * 36) + (driftWave * 10)
                visible: opacity > 0.01
                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(1.0, 0.28, 0.62, 0.95)
                    shadowBlur: 1.0
                    shadowScale: 1.45
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
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
            var hiddenNotification = root.currentNotification
            NotificationState.markPresented(hiddenNotification)
            root.currentNotification = null
            islandView.collapse()
            islandView.resetSwipe()
            showNextUnseen()
        }
    }

    // ─── Drag-to-dismiss + Hover MouseArea ──────────────────────────────
    readonly property real dismissThreshold: 100
    readonly property bool isDragging: islandView.isDragging

    function dismissNotification() {
        var dismissed = root.currentNotification
        root.tryDismissNotification(dismissed)
        root.currentNotification = null

        islandView.collapse()
        islandView.resetSwipe()
        showNextUnseen()
    }

    function dismissNotificationFromAutoHide() {
        var dismissed = root.currentNotification
        root.tryDismissNotification(dismissed)
        root.currentNotification = null

        islandView.collapse()
        islandView.resetSwipe()
        showNextUnseen()
    }

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
