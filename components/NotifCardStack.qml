import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Notifications
import "../core"

Item {
    id: root

    property var allNotifications: NotificationState.stackNotifications
    property var islandNotification: null
    property string expandedGroupKey: ""
    property string visualExpandedGroupKey: ""
    property string pendingExpandGroupKey: ""
    property bool isFadingOut: false
    property var stackReadyKeys: []
    property var pendingStackKeys: []
    property var heightRetainedStackKeys: []
    property var appearedNotificationKeys: []
    readonly property int stackRevision: NotificationState.stackRevision
    readonly property int stackPromotionRevision: NotificationState.stackPromotionRevision

    readonly property int cardWidth: 280
    readonly property int cardHeight: 56
    readonly property int stackCardHeight: 64
    readonly property int spacing: 6
    readonly property int entryOffset: 72
    readonly property int stackCollapseDelay: 560
    readonly property int stackExpandDelay: 180
    readonly property int stackHeightCollapseDelay: 460
    readonly property int promotionShiftDistance: cardHeight + spacing
    property var promotedGhostNotification: null
    property string promotedGhostAppName: ""
    property string promotedGhostSummary: ""
    property real promotedGhostOffsetY: 0
    property real promotedGhostOpacity: 0
    property bool promotedGhostVisible: false
    property bool pendingPromotionAnimation: false
    property bool pendingPromotionListShift: false
    property real stackShiftOffsetY: 0
    property real viewportHeight: 0
    property real bottomFadeHeight: 0
    property Item promotionOverlayParent: null
    property real promotionOverlayX: 0
    property real promotionOverlayY: 0
    property real promotionOverlayZ: 1000

    function bottomFadeOpacity(itemY, itemHeight) {
        if (root.viewportHeight <= 0 || root.bottomFadeHeight <= 0)
            return 1.0

        const fadeStart = root.viewportHeight - root.bottomFadeHeight
        const fadeAnchor = itemY + itemHeight
        return Math.max(0.0, Math.min(1.0, (root.viewportHeight - fadeAnchor) / Math.max(1.0, root.viewportHeight - fadeStart)))
    }

    function bottomBlurProgress(itemY, itemHeight) {
        return 1.0 - bottomFadeOpacity(itemY, itemHeight)
    }

    function notificationAppName(notification) {
        const label = notification ? (((notification.appName || notification.desktopEntry || "System") + "").trim()) : "System"
        return label.length > 0 ? label : "System"
    }

    function notificationSenderName(notification) {
        if (!notification)
            return "System"

        const summary = ((notification.summary || "") + "").trim()
        if (summary.length > 0)
            return summary

        const body = ((notification.body || "") + "").trim()
        const separator = body.indexOf(":")
        if (separator > 0 && separator < 64)
            return body.slice(0, separator).trim()

        return notificationAppName(notification)
    }

    function notificationSummaryText(notification) {
        return notification ? (((notification.summary || "") + "").trim()) : ""
    }

    function notificationBodyText(notification) {
        return notification ? (((notification.body || "") + "").trim()) : ""
    }

    function notificationCountText(count) {
        return count + (count === 1 ? " notification" : " notifications")
    }

    function cardPrimaryText(notification, collapsedTopCard, senderName) {
        return collapsedTopCard ? senderName : notificationSummaryText(notification)
    }

    function cardSecondaryText(notification, collapsedTopCard, count) {
        return collapsedTopCard ? notificationCountText(count) : notificationBodyText(notification)
    }

    function notificationGroupKey(notification) {
        const appName = notificationAppName(notification).toLowerCase()
        const senderName = notificationSenderName(notification).toLowerCase()
        return appName + "\u0001" + senderName
    }

    function notificationAnimationKey(notification) {
        return notification ? ("notif:" + NotificationState.notificationUid(notification)) : ""
    }

    function notificationHasAppeared(notification) {
        var key = notificationAnimationKey(notification)
        return key !== "" && appearedNotificationKeys.indexOf(key) !== -1
    }

    function markNotificationAppeared(notification) {
        var key = notificationAnimationKey(notification)
        if (key === "" || appearedNotificationKeys.indexOf(key) !== -1)
            return

        appearedNotificationKeys = appearedNotificationKeys.concat(key)
    }

    function groupModelItemForNotification(notification) {
        if (!notification)
            return null

        for (var i = 0; i < groupModel.count; i++) {
            var group = groupModel.get(i)
            var notifications = group.notifications || []
            for (var j = 0; j < notifications.length; j++) {
                if (notifications[j] === notification)
                    return group
            }
        }

        return null
    }

    function promotedPrimary(notification, group) {
        if (group && group.stacked && root.expandedGroupKey !== group.groupKey)
            return group.senderName

        return notificationSummaryText(notification)
    }

    function promotedSecondary(notification, group) {
        if (group && group.stacked && root.expandedGroupKey !== group.groupKey)
            return notificationCountText(group.notifCount)

        return notificationBodyText(notification)
    }

    function prepareStackPromotionAnimation(notification) {
        if (!notification)
            return

        var group = groupModelItemForNotification(notification)
        pendingPromotionAnimation = true
        pendingPromotionListShift = group && group.notifCount > 1
        promotedGhostNotification = notification
        promotedGhostAppName = promotedPrimary(notification, group)
        promotedGhostSummary = promotedSecondary(notification, group)
        promotedGhostOffsetY = 0
        promotedGhostOpacity = 1
        promotedGhostVisible = false
    }

    function startPendingPromotionAnimation() {
        if (!pendingPromotionAnimation)
            return

        pendingPromotionAnimation = false
        promotionAnimation.stop()
        stackShiftOffsetY = pendingPromotionListShift ? promotionShiftDistance : 0
        promotedGhostOffsetY = 0
        promotedGhostOpacity = 1
        promotedGhostVisible = true
        promotionAnimation.restart()
    }

    function stackReadyForGroup(groupKey) {
        return stackReadyKeys.indexOf(groupKey) !== -1
    }

    function stackHeightCollapsedForGroup(groupKey) {
        return stackReadyKeys.indexOf(groupKey) !== -1 && heightRetainedStackKeys.indexOf(groupKey) === -1
    }

    function stackStorageKey(groupKey) {
        return groupKey.indexOf("group:") === 0 ? groupKey.slice(6) : groupKey
    }

    function retainStackHeight(groupKey) {
        var key = stackStorageKey(groupKey)
        if (key === "")
            return

        var retained = heightRetainedStackKeys.slice()
        if (retained.indexOf(key) === -1)
            retained.push(key)
        heightRetainedStackKeys = retained
    }

    function scheduleStackCollapse(groupKey) {
        if (stackReadyKeys.indexOf(groupKey) !== -1 || pendingStackKeys.indexOf(groupKey) !== -1)
            return

        pendingStackKeys = pendingStackKeys.concat(groupKey)
        stackCollapseTimer.restart()
    }

    function finishPendingStackCollapses() {
        if (!pendingStackKeys || pendingStackKeys.length === 0)
            return

        var ready = stackReadyKeys.slice()
        var retained = heightRetainedStackKeys.slice()
        for (var i = 0; i < pendingStackKeys.length; i++) {
            var key = pendingStackKeys[i]
            if (ready.indexOf(key) === -1)
                ready.push(key)
            if (retained.indexOf(key) === -1)
                retained.push(key)
        }

        pendingStackKeys = []
        heightRetainedStackKeys = retained
        stackReadyKeys = ready
        syncGroups()
        stackHeightCollapseTimer.restart()
    }

    function releaseStackHeights() {
        if (!heightRetainedStackKeys || heightRetainedStackKeys.length === 0)
            return

        heightRetainedStackKeys = []
        syncGroups()
    }

    function finishPendingStackExpansion() {
        if (pendingExpandGroupKey === "" || expandedGroupKey !== pendingExpandGroupKey) {
            pendingExpandGroupKey = ""
            return
        }

        visualExpandedGroupKey = pendingExpandGroupKey
        pendingExpandGroupKey = ""
    }

    function cleanStackTransitionState(activeStackKeys) {
        var nextReady = []
        for (var r = 0; r < stackReadyKeys.length; r++) {
            if (activeStackKeys.indexOf(stackReadyKeys[r]) !== -1)
                nextReady.push(stackReadyKeys[r])
        }
        if (nextReady.length !== stackReadyKeys.length)
            stackReadyKeys = nextReady

        var nextHeightRetained = []
        for (var h = 0; h < heightRetainedStackKeys.length; h++) {
            if (activeStackKeys.indexOf(heightRetainedStackKeys[h]) !== -1)
                nextHeightRetained.push(heightRetainedStackKeys[h])
        }
        if (nextHeightRetained.length !== heightRetainedStackKeys.length) {
            heightRetainedStackKeys = nextHeightRetained
            if (heightRetainedStackKeys.length === 0)
                stackHeightCollapseTimer.stop()
        }

        var nextPending = []
        for (var p = 0; p < pendingStackKeys.length; p++) {
            if (activeStackKeys.indexOf(pendingStackKeys[p]) !== -1)
                nextPending.push(pendingStackKeys[p])
        }
        if (nextPending.length !== pendingStackKeys.length) {
            pendingStackKeys = nextPending
            if (pendingStackKeys.length === 0)
                stackCollapseTimer.stop()
        }
    }

    function cleanAppearedNotificationKeys() {
        var activeKeys = []
        if (allNotifications) {
            for (var i = 0; i < allNotifications.length; i++) {
                if (allNotifications[i])
                    activeKeys.push(notificationAnimationKey(allNotifications[i]))
            }
        }

        var nextAppeared = []
        for (var a = 0; a < appearedNotificationKeys.length; a++) {
            if (activeKeys.indexOf(appearedNotificationKeys[a]) !== -1)
                nextAppeared.push(appearedNotificationKeys[a])
        }

        if (nextAppeared.length !== appearedNotificationKeys.length)
            appearedNotificationKeys = nextAppeared
    }

    function buildGroups() {
        cleanAppearedNotificationKeys()

        if (!allNotifications || allNotifications.length === 0) {
            cleanStackTransitionState([])
            return []
        }

        var groups = {}
        var groupOrder = []
        for (var j = 0; j < allNotifications.length; j++) {
            var notification = allNotifications[j]
            if (!notification || notification === islandNotification)
                continue

            var key = notificationGroupKey(notification)
            if (!groups[key]) {
                groups[key] = {
                    "appName": notificationAppName(notification),
                    "senderName": notificationSenderName(notification),
                    "notifications": []
                }
                groupOrder.push(key)
            }
            groups[key].notifications.push(notification)
        }

        var result = []
        var activeStackKeys = []
        for (var g = 0; g < groupOrder.length; g++) {
            var groupKey = groupOrder[g]
            var group = groups[groupKey]
            var notifications = group.notifications
            if (notifications.length >= 3) {
                activeStackKeys.push(groupKey)
                scheduleStackCollapse(groupKey)
            }

            result.push({
                "groupKey": "group:" + groupKey,
                "appName": group.appName,
                "senderName": group.senderName,
                "notifCount": notifications.length,
                "stacked": notifications.length >= 3 && stackReadyForGroup(groupKey),
                "heightCollapsed": notifications.length >= 3 && stackHeightCollapsedForGroup(groupKey),
                "notifications": notifications,
                "firstNotif": notifications[0]
            })
        }

        cleanStackTransitionState(activeStackKeys)

        return result
    }

    function modelIndexForKey(groupKey) {
        for (var i = 0; i < groupModel.count; i++) {
            if (groupModel.get(i).groupKey === groupKey)
                return i
        }
        return -1
    }

    function updateGroupModelItem(index, group) {
        groupModel.setProperty(index, "groupKey", group.groupKey)
        groupModel.setProperty(index, "appName", group.appName)
        groupModel.setProperty(index, "senderName", group.senderName)
        groupModel.setProperty(index, "notifCount", group.notifCount)
        groupModel.setProperty(index, "stacked", group.stacked)
        groupModel.setProperty(index, "heightCollapsed", group.heightCollapsed)
        groupModel.setProperty(index, "notifications", group.notifications)
        groupModel.setProperty(index, "firstNotif", group.firstNotif)
    }

    function syncGroups() {
        var nextGroups = buildGroups()
        if (nextGroups.length === 0) {
            expandedGroupKey = ""
            visualExpandedGroupKey = ""
            pendingExpandGroupKey = ""
            stackExpandTimer.stop()
            if (pendingPromotionAnimation) {
                fadeOutTimer.stop()
                groupModel.clear()
                isFadingOut = false
                startPendingPromotionAnimation()
                return
            }

            if (groupModel.count > 0 && !isFadingOut) {
                isFadingOut = true
                fadeOutTimer.restart()
            }
            return
        }

        fadeOutTimer.stop()
        isFadingOut = false

        var nextKeys = []
        for (var k = 0; k < nextGroups.length; k++)
            nextKeys.push(nextGroups[k].groupKey)

        for (var r = groupModel.count - 1; r >= 0; r--) {
            if (nextKeys.indexOf(groupModel.get(r).groupKey) === -1)
                groupModel.remove(r)
        }

        if (expandedGroupKey !== "" && nextKeys.indexOf(expandedGroupKey) === -1)
            expandedGroupKey = ""
        if (visualExpandedGroupKey !== "" && nextKeys.indexOf(visualExpandedGroupKey) === -1)
            visualExpandedGroupKey = ""
        if (pendingExpandGroupKey !== "" && nextKeys.indexOf(pendingExpandGroupKey) === -1) {
            pendingExpandGroupKey = ""
            stackExpandTimer.stop()
        }

        for (var target = 0; target < nextGroups.length; target++) {
            var group = nextGroups[target]
            var currentIndex = modelIndexForKey(group.groupKey)
            if (currentIndex === -1) {
                groupModel.insert(target, group)
            } else {
                if (currentIndex !== target)
                    groupModel.move(currentIndex, target, 1)
                updateGroupModelItem(target, group)
            }
        }

        startPendingPromotionAnimation()
    }

    function toggleGroup(groupKey) {
        if (expandedGroupKey === groupKey) {
            stackExpandTimer.stop()
            pendingExpandGroupKey = ""
            visualExpandedGroupKey = ""
            retainStackHeight(groupKey)
            expandedGroupKey = ""
            syncGroups()
            stackHeightCollapseTimer.restart()
            return
        }

        if (expandedGroupKey !== "") {
            retainStackHeight(expandedGroupKey)
            stackHeightCollapseTimer.restart()
        }

        expandedGroupKey = groupKey
        visualExpandedGroupKey = ""
        pendingExpandGroupKey = groupKey
        syncGroups()
        stackExpandTimer.restart()
    }

    ListModel {
        id: groupModel
        dynamicRoles: true
    }

    Component.onCompleted: syncGroups()
    onStackPromotionRevisionChanged: prepareStackPromotionAnimation(NotificationState.promotedStackNotification)
    onStackRevisionChanged: syncGroups()
    onAllNotificationsChanged: syncGroups()
    onIslandNotificationChanged: syncGroups()

    implicitWidth: cardWidth
    implicitHeight: {
        if (groupModel.count === 0)
            return promotedGhostVisible ? cardHeight : 0

        var h = 0
        for (var i = 0; i < groupModel.count; i++) {
            var group = groupModel.get(i)
            var expanded = expandedGroupKey === group.groupKey
            var groupHeight = (group.notifCount * cardHeight) + (Math.max(0, group.notifCount - 1) * spacing)
            if (group.stacked && expanded) {
                h += groupHeight
            } else if (group.stacked && group.heightCollapsed) {
                h += stackCardHeight
            } else {
                h += groupHeight
            }

            if (i < groupModel.count - 1)
                h += spacing
        }
        return h
    }

    opacity: isFadingOut ? 0.0 : 1.0
    visible: groupModel.count > 0 || isFadingOut || promotedGhostVisible
    Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }
    Behavior on implicitHeight { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }

    Timer {
        id: fadeOutTimer
        interval: AnimationConfig.durationModerate
        repeat: false
        onTriggered: {
            groupModel.clear()
            root.isFadingOut = false
        }
    }

    Timer {
        id: stackCollapseTimer
        interval: root.stackCollapseDelay
        repeat: false
        onTriggered: root.finishPendingStackCollapses()
    }

    Timer {
        id: stackExpandTimer
        interval: root.stackExpandDelay
        repeat: false
        onTriggered: root.finishPendingStackExpansion()
    }

    Timer {
        id: stackHeightCollapseTimer
        interval: root.stackHeightCollapseDelay
        repeat: false
        onTriggered: root.releaseStackHeights()
    }

    ParallelAnimation {
        id: promotionAnimation
        NumberAnimation { target: root; property: "stackShiftOffsetY"; to: 0; duration: 360; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "promotedGhostOffsetY"; to: -root.promotionShiftDistance; duration: 360; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "promotedGhostOpacity"; to: 0; duration: 360; easing.type: Easing.OutQuad }
        onStopped: {
            root.stackShiftOffsetY = 0
            root.promotedGhostVisible = false
            root.promotedGhostNotification = null
            root.promotedGhostOpacity = 0
            root.promotedGhostOffsetY = 0
            root.pendingPromotionListShift = false
        }
    }

    ListView {
        id: cardList
        width: parent.width
        height: contentHeight
        interactive: false
        spacing: root.spacing
        model: groupModel

        transform: Translate {
            y: root.stackShiftOffsetY
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 280; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; to: 0.92; duration: 280; easing.type: Easing.OutQuad }
            NumberAnimation { property: "y"; to: -root.promotionShiftDistance; duration: 360; easing.type: Easing.OutCubic }
        }

        removeDisplaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 360; easing.type: Easing.OutQuad }
        }

        addDisplaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 360; easing.type: Easing.OutQuad }
        }

        delegate: Item {
                id: cardRoot
                width: root.cardWidth
                height: heightCollapsedGroup && !heightExpanded ? root.stackCardHeight : expandedHeight

                property bool appeared: false
                property string grpKey: groupKey
                property string grpAppName: appName
                property string grpSenderName: senderName
                property int grpCount: notifCount
                property bool stackedGroup: stacked
                property bool heightCollapsedGroup: heightCollapsed
                property var firstNotification: firstNotif
                property var notifItems: notifications || []
                property bool heightExpanded: root.expandedGroupKey === grpKey
                property bool expanded: root.visualExpandedGroupKey === grpKey
                readonly property int expandedHeight: (notifItems.length * root.cardHeight) + (Math.max(0, notifItems.length - 1) * root.spacing)
                property real entryOffsetY: 0
                property real stackProgress: stackedGroup ? 1.0 : 0.0

                opacity: appeared ? 1.0 : 0.0
                scale: appeared ? 1.0 : 0.92
                Component.onCompleted: appeared = true
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack } }
                Behavior on entryOffsetY { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
                Behavior on stackProgress { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }

                transform: Translate {
                    y: cardRoot.entryOffsetY
                }

                Repeater {
                    model: cardRoot.notifItems

                    Rectangle {
                        id: notificationCard
                        property var notification: modelData
                        property bool appeared: root.notificationHasAppeared(notification)
                        readonly property int totalCount: cardRoot.notifItems.length
                        readonly property int itemIndex: Math.max(0, cardRoot.notifItems.indexOf(notification))
                        readonly property int collapsedLayer: Math.min(2, itemIndex)
                        readonly property real expandedY: itemIndex * (root.cardHeight + root.spacing)
                        readonly property real collapsedY: collapsedLayer * 4
                        readonly property real targetY: cardRoot.expanded ? expandedY : collapsedY
                        readonly property real targetOpacity: cardRoot.expanded ? 1.0 : (collapsedLayer === 0 ? 1.0 : collapsedLayer === 1 ? 0.82 : 0.64)
                        readonly property real targetScale: cardRoot.expanded ? 1.0 : (collapsedLayer === 0 ? 1.0 : collapsedLayer === 1 ? 0.985 : 0.97)
                        readonly property real entryOffsetY: appeared ? 0 : -(expandedY + root.entryOffset)
                        readonly property bool collapsedTopCard: cardRoot.stackProgress >= 0.95 && !cardRoot.expanded && itemIndex === 0
                        readonly property bool bottomEffectEnabled: cardRoot.expanded && itemIndex >= 6
                        readonly property real viewportY: cardRoot.y + root.stackShiftOffsetY + y + cardRoot.entryOffsetY
                        readonly property real fadeOpacity: bottomEffectEnabled ? root.bottomFadeOpacity(viewportY, height) : 1.0
                        readonly property real blurProgress: bottomEffectEnabled ? root.bottomBlurProgress(viewportY, height) : 0.0

                        width: cardRoot.width
                        height: root.cardHeight
                        radius: 22
                        color: "#000000"
                        visible: cardRoot.stackProgress < 0.95 || cardRoot.expanded || itemIndex < 3
                        y: expandedY + ((targetY - expandedY) * cardRoot.stackProgress) + entryOffsetY
                        z: cardRoot.expanded || cardRoot.stackProgress < 0.95 ? (totalCount - itemIndex) : (100 - itemIndex)
                        opacity: (appeared ? 1.0 : 0.0) * (1.0 + ((targetOpacity - 1.0) * cardRoot.stackProgress)) * fadeOpacity
                        scale: 1.0 + ((targetScale - 1.0) * cardRoot.stackProgress)
                        Component.onCompleted: if (!appeared) appearTimer.restart()

                        Timer {
                            id: appearTimer
                            interval: 1
                            repeat: false
                            onTriggered: root.markNotificationAppeared(notification)
                        }

                        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
                        layer.enabled: blurProgress > 0.01
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: AnimationConfig.blurMaxLight
                            blur: Math.min(1.0, blurProgress * 1.25)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            opacity: collapsedTopCard || cardRoot.expanded || cardRoot.stackProgress < 0.95 ? 1.0 : 0.0

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                            AppIcon {
                                text: "\udb80\udd70"
                                font.pixelSize: 18
                                color: Theme.info
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                AppText {
                                    text: root.cardPrimaryText(notification, collapsedTopCard, cardRoot.grpSenderName)
                                    color: "#ffffff"
                                    font { pixelSize: 14; weight: Font.DemiBold }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                AppText {
                                    text: root.cardSecondaryText(notification, collapsedTopCard, cardRoot.grpCount)
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, cardMouse.containsMouse ? 0.15 : 0.0)

                            Behavior on border.color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            enabled: !cardRoot.stackedGroup || cardRoot.expanded || itemIndex === 0
                            hoverEnabled: enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cardRoot.stackedGroup && !cardRoot.expanded) {
                                    root.toggleGroup(cardRoot.grpKey)
                                } else if (notification) {
                                    NotificationState.removeStackNotification(notification)
                                    notification.dismiss()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: stackedGroup
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 8
                    anchors.rightMargin: 10
                    implicitWidth: badgeText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 11
                    color: Theme.info
                    z: 200

                    AppText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: grpCount
                        color: "#ffffff"
                        font { pixelSize: 11; weight: Font.Bold }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroup(cardRoot.grpKey)
                    }
            }
        }
    }

    Rectangle {
        parent: root.promotionOverlayParent ? root.promotionOverlayParent : root
        visible: root.visible && root.promotedGhostVisible && root.promotedGhostNotification !== null
        width: root.cardWidth
        height: root.cardHeight
        radius: 22
        color: "#000000"
        x: root.promotionOverlayParent ? root.promotionOverlayX : 0
        y: (root.promotionOverlayParent ? root.promotionOverlayY : 0) + root.promotedGhostOffsetY
        z: root.promotionOverlayZ
        opacity: root.promotedGhostOpacity

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            AppIcon {
                text: "\udb80\udd70"
                font.pixelSize: 18
                color: Theme.info
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                AppText {
                    text: root.promotedGhostAppName
                    color: "#ffffff"
                    font { pixelSize: 14; weight: Font.DemiBold }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                AppText {
                    text: root.promotedGhostSummary
                    color: "#cccccc"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: text !== ""
                }
            }
        }
    }
}
