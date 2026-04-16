import QtQuick
import QtQuick.Layouts
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
    property bool notifExpanded: false   // hover-expanded state
    property bool notifHovered: false

    color: isNotifIsland ? "#000000" : Theme.bgPanel
    radius: isNotifIsland ? (notifExpanded ? 24 : 22) : Theme.radiusPanel

    readonly property int compactIslandHeight: 64
    readonly property int expandedIslandHeight: 120

    // Blur transition when notification content changes
    property var displayedNotification: null
    property real notifBlur: 0.0

    onCurrentNotificationChanged: {
        if (!currentNotification) {
            displayedNotification = null
            notifBlurPulse.stop()
            notifBlur = 0.0
        } else if (!displayedNotification) {
            displayedNotification = currentNotification
        } else if (displayedNotification !== currentNotification) {
            if (notifBlurPulse.running) notifBlurPulse.stop()
            notifBlurPulse.start()
        }
    }

    SequentialAnimation {
        id: notifBlurPulse
        NumberAnimation { target: root; property: "notifBlur"; to: 1.0; duration: 150; easing.type: Easing.InQuad }
        ScriptAction { script: root.displayedNotification = root.currentNotification }
        NumberAnimation { target: root; property: "notifBlur"; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
    }

    implicitWidth: isNotifIsland ? (notifExpanded ? 420 : 280) : (iconsRow.width + 12)
    implicitHeight: isNotifIsland ? (notifExpanded ? expandedIslandHeight : compactIslandHeight) : (iconsRow.height + 4)

    // Blur spike on island transition
    property real animBlur: 0.0
    onIsNotifIslandChanged: blurPulse.restart()

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: 200; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
    }

    // Smooth Transitions
    Behavior on color { ColorAnimation { duration: 400 } }
    Behavior on radius { NumberAnimation { duration: 500; easing.type: Easing.OutElastic; easing.amplitude: 0.5; easing.period: 0.6 } }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutElastic
            easing.amplitude: 0.8; easing.period: 0.7
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutElastic
            easing.amplitude: 0.8; easing.period: 0.7
        }
    }

    // ─── Hover expand timer ────────────────────────────────────────────
    property real hoverProgress: 0.0   // 0.0 → 1.0 over 1 second

    Timer {
        id: hoverExpandTimer
        interval: 16
        repeat: true
        onTriggered: {
            if (root.notifHovered && root.isNotifIsland && !root.notifExpanded) {
                root.hoverProgress = Math.min(1.0, root.hoverProgress + 16 / 1000)
                if (root.hoverProgress >= 1.0) {
                    root.notifExpanded = true
                    stop()
                }
            }
        }
    }

    // Secondary Effects (Blur)
    layer.enabled: animBlur > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 32
        blur: root.animBlur
    }

    // ─── Notification tracking ─────────────────────────────────────────
    // Island shows the LATEST notification only.
    // Remaining notifications are shown as cards below the island (in bar.qml).

    ListView {
        id: notifTracker
        visible: false
        width: 0; height: 0
        model: NotificationState.activeNotifications
        delegate: Item {}
        onCountChanged: {
            if (count === 0) {
                root.currentNotification = null
                notifAutoHide.stop()
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
            root.isNotifIsland = true
            notifAutoHide.restart()
        }
    }

    Timer {
        id: notifAutoHide
        interval: 8000
        repeat: false
        onTriggered: {
            if (root.currentNotification) {
                root.currentNotification.dismiss()
                root.currentNotification = null
            }
            // If more notifications remain, pick next
            var items = NotificationState.activeNotifications.values
            if (items && items.length > 0) {
                root.currentNotification = items[items.length - 1]
                notifAutoHide.restart()
            } else {
                root.isNotifIsland = false
            }
        }
    }

    property bool popoutOpen: false
    property Item popoutItem: popout

    onPopoutOpenChanged: {
        if (popoutOpen) {
            // Hide island when popout opens — notifications go to the list
            root.isNotifIsland = false
            root.notifExpanded = false
            notifAutoHide.stop()
        } else {
            // When popout closes, show island if there are pending notifications
            var items = NotificationState.activeNotifications.values
            if (items && items.length > 0) {
                root.currentNotification = items[items.length - 1]
                root.isNotifIsland = true
                notifAutoHide.restart()
            }
        }
    }

    // ─── Данные Wi-Fi ───────────────────────────────────────────────────
    property bool wifiConnected: NetworkState.wifiConnected
    property string wifiEssid: NetworkState.wifiEssid

    property string pendingEssid: NetworkState.pendingEssid
    property bool pendingConnected: NetworkState.pendingConnected

    // ─── Данные Bluetooth ───────────────────────────────────────────────
    property string displayBtStatus: NetworkState.btStatus
    property string pendingBtStatus: NetworkState.pendingBtStatus

    Binding {
        target: root
        property: "displayBtStatus"
        value: NetworkState.btStatus
        when: !btCrossfade.running
    }

    // ─── Данные Math Mode ───────────────────────────────────────────
    property bool mathActive: false

    // ─── Crossfade: Wi-Fi ───────────────────────────────────────────────
    SequentialAnimation {
        id: wifiCrossfade
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                NetworkState.wifiEssid = NetworkState.pendingEssid;
                NetworkState.wifiConnected = NetworkState.pendingConnected;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }
    
    Connections {
        target: NetworkState
        function onWifiUpdateTriggered() {
            wifiCrossfade.restart()
        }
        function onBtUpdateTriggered() {
            btCrossfade.restart()
        }
    }

    // ─── Crossfade: Bluetooth ───────────────────────────────────────────
    SequentialAnimation {
        id: btCrossfade
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { 
            script: {
                root.displayBtStatus = NetworkState.pendingBtStatus;
                NetworkState.btStatus = NetworkState.pendingBtStatus;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }



    // ─── Content 1: Normal CC icons ──────────────────────────────────────
    Row {
        id: iconsRow
        anchors.centerIn: parent
        spacing: 0
        opacity: root.isNotifIsland ? 0.0 : 1.0
        scale: root.isNotifIsland ? 0.6 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

        // Bluetooth icon
        Rectangle {
            id: btRect
            width: 44
            height: 36
            radius: 18
            color: "transparent"

            Text {
                id: btIcon
                anchors.centerIn: parent
                property real blurValue: 0.0

                text: {
                    switch (root.displayBtStatus) {
                        case "connected": return "\udb80\udcaf";
                        case "on":        return "\udb80\udcaf" + "?";
                        default:          return "\udb80\udcb2";
                    }
                }
                color: (root.displayBtStatus === "on" || root.displayBtStatus === "connected") ? Theme.textDark : Theme.textSecondary
                font { pixelSize: 18; bold: true }
                Behavior on color { ColorAnimation { duration: 300 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: btIcon.blurValue
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popoutOpen = !root.popoutOpen
                onPressed: btRect.opacity = 0.7
                onReleased: btRect.opacity = 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }

        // Wi-Fi icon
        Rectangle {
            id: wifiRect
            width: 44
            height: 36
            radius: 18
            color: "transparent"

            Text {
                id: wifiIcon
                anchors.centerIn: parent
                property real blurValue: 0.0

                text: root.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
                color: root.wifiConnected ? Theme.textDark : Theme.textSecondary
                font { pixelSize: 18; bold: true }
                Behavior on color { ColorAnimation { duration: 300 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: wifiIcon.blurValue
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popoutOpen = !root.popoutOpen
                onPressed: wifiRect.opacity = 0.7
                onReleased: wifiRect.opacity = 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }

    // ─── Content 2: Notification Island Overlay ───────────────────────────
    Item {
        id: notifIslandContent
        anchors.fill: parent
        opacity: root.isNotifIsland ? 1.0 : 0.0
        scale: root.isNotifIsland ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

        // ── Compact view (summary of all groups) ─────────────────────────
        RowLayout {
            id: compactView
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            opacity: root.notifExpanded ? 0.0 : 1.0
            scale: root.notifExpanded ? 0.8 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

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
                    blurMax: 16
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

            // Vertical hover progress bar
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
                    Behavior on height { NumberAnimation { duration: 18 } }
                }
            }
        }

        // ── Expanded view (single notification detail) ──────────────────
        RowLayout {
            id: expandedView
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            opacity: root.notifExpanded ? 1.0 : 0.0
            scale: root.notifExpanded ? 1.0 : 0.8
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

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
                    blurMax: 16
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
    }

    // ─── Drag-to-dismiss + Hover MouseArea ──────────────────────────────
    property real dragOffsetX: 0.0
    property real dragOffsetY: 0.0
    property bool isDragging: false
    readonly property real dismissThreshold: 100

    function dismissNotification() {
        if (root.currentNotification) {
            root.currentNotification.dismiss()
            root.currentNotification = null
        }
        // If more notifications remain, pick next
        var items = NotificationState.activeNotifications.values
        if (items && items.length > 0) {
            root.currentNotification = items[items.length - 1]
            notifAutoHide.restart()
        } else {
            root.isNotifIsland = false
        }
        root.notifExpanded = false
        root.dragOffsetX = 0
        root.dragOffsetY = 0
        root.isDragging = false
        notifAutoHide.stop()
    }

    MouseArea {
        id: islandMouseArea
        anchors.fill: parent
        visible: root.isNotifIsland
        hoverEnabled: true
        z: 10

        // ── Hover logic ──────────────────────────────────────────────────
        onEntered: {
            if (!root.isDragging) {
                root.notifHovered = true
                root.hoverProgress = 0.0
                hoverExpandTimer.start()
                notifAutoHide.stop()
            }
        }

        onExited: {
            if (!root.isDragging) {
                root.notifHovered = false
                hoverExpandTimer.stop()
                root.hoverProgress = 0.0
                root.notifExpanded = false
                notifAutoHide.restart()
            }
        }

        // ── Click = dismiss current notification ──────────────────────────
        onClicked: function(mouse) {
            if (!root.isDragging) {
                root.dismissNotification()
            }
        }

        // ── Drag-to-dismiss handled by DragHandler below ────────────────
    }

    DragHandler {
        id: dragHandler
        target: null  // we handle offset manually
        enabled: root.isNotifIsland

        onTranslationChanged: function() {
            root.isDragging = true
            root.dragOffsetX = translation.x
            root.dragOffsetY = translation.y
        }

        onActiveChanged: {
            if (!active) {
                // Released — check threshold
                var dist = Math.sqrt(root.dragOffsetX * root.dragOffsetX + root.dragOffsetY * root.dragOffsetY)
                if (dist > root.dismissThreshold) {
                    root.dismissNotification()
                } else {
                    // Enable behavior animations first, then animate offsets to 0
                    root.isDragging = false
                    // Small delay so the Behavior catches the value change
                    snapBackTimer.start()
                }
            }
        }
    }

    // Timer to smoothly animate drag offsets back to 0
    Timer {
        id: snapBackTimer
        interval: 1
        repeat: false
        onTriggered: {
            root.dragOffsetX = 0
            root.dragOffsetY = 0
        }
    }

    // Apply drag offset + visual feedback to the island content
    transform: [
        Translate {
            y: root.isNotifIsland ? (root.notifExpanded ? 48 : 18) : 0
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        },
        Translate {
            x: root.isDragging ? root.dragOffsetX : 0
            y: root.isDragging ? root.dragOffsetY : 0
            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        }
    ]

    // Fade out as drag distance increases, smoothly return to 1.0
    opacity: {
        if (root.isDragging) {
            var dist = Math.sqrt(root.dragOffsetX * root.dragOffsetX + root.dragOffsetY * root.dragOffsetY)
            return Math.max(0.0, 1.0 - (dist / root.dismissThreshold) * 0.7)
        }
        return 1.0
    }
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

    // ─── Попаут ─────────────────────────────────────────────────────────

    ControlCenterPopout {
        id: popout
        isOpen: root.popoutOpen

        wifiConnected: NetworkState.wifiConnected
        wifiEssid: NetworkState.wifiEssid
        btStatus: root.displayBtStatus

        onCloseRequested: root.popoutOpen = false
        onRequestMathDetails: MathState.popoutOpen = true

        anchors.top: iconsRow.bottom
        anchors.topMargin: 6
        anchors.right: iconsRow.right

        // Анимация открывается из центра между иконками Wi-Fi и Bluetooth
        originX: popout.popoutWidth - (iconsRow.width / 2)
    }
}
