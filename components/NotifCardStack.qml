import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../core"

Item {
    id: root

    property var allNotifications: NotificationState.unpresentedNotifications
    property var islandNotification: null
    property string expandedAppName: ""
    property bool isFadingOut: false

    readonly property int cardWidth: 280
    readonly property int cardHeight: 56
    readonly property int stackCardHeight: 64
    readonly property int spacing: 6

    function buildGroups() {
        if (!allNotifications || allNotifications.length === 0)
            return []

        var rest = []
        for (var i = 0; i < allNotifications.length; i++) {
            if (allNotifications[i] !== islandNotification)
                rest.push(allNotifications[i])
        }

        if (rest.length === 0)
            return []

        var groups = {}
        var groupOrder = []
        for (var j = 0; j < rest.length; j++) {
            var notification = rest[j]
            var key = notification.appName || "System"
            if (!groups[key]) {
                groups[key] = []
                groupOrder.push(key)
            }
            groups[key].push(notification)
        }

        var result = []
        for (var g = 0; g < groupOrder.length; g++) {
            var name = groupOrder[g]
            var notifications = groups[name]
            result.push({
                "appName": name,
                "notifCount": notifications.length,
                "isStacked": notifications.length >= 3,
                "notifications": notifications,
                "firstNotif": notifications[0]
            })
        }

        return result
    }

    function toggleGroup(appName) {
        expandedAppName = expandedAppName === appName ? "" : appName
    }

    readonly property var groups: buildGroups()
    property var displayGroups: groups

    implicitWidth: cardWidth
    implicitHeight: {
        var groups = root.displayGroups
        if (!groups || groups.length === 0)
            return 0

        var h = 0
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i]
            var notifications = group.notifications
            var expanded = expandedAppName === group.appName
            if (group.isStacked && expanded) {
                h += (notifications.length * cardHeight) + (Math.max(0, notifications.length - 1) * spacing)
            } else if (group.isStacked) {
                h += stackCardHeight
            } else {
                h += cardHeight
            }

            if (i < groups.length - 1)
                h += spacing
        }
        return h
    }

    opacity: isFadingOut ? 0.0 : 1.0
    visible: (displayGroups && displayGroups.length > 0) || isFadingOut
    Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

    onGroupsChanged: {
        if (groups.length > 0) {
            displayGroups = groups
            fadeOutTimer.stop()
            isFadingOut = false
        } else if (displayGroups && displayGroups.length > 0 && !isFadingOut) {
            isFadingOut = true
            fadeOutTimer.restart()
        }
    }

    Timer {
        id: fadeOutTimer
        interval: AnimationConfig.durationModerate
        repeat: false
        onTriggered: {
            root.displayGroups = []
            root.isFadingOut = false
        }
    }

    Column {
        id: cardList
        anchors.fill: parent
        spacing: root.spacing

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 360
                easing.type: Easing.OutQuad
            }
        }

        Repeater {
            model: root.displayGroups

            Item {
                id: cardRoot
                width: root.cardWidth
                height: isStacked ? (expanded ? expandedHeight : root.stackCardHeight) : root.cardHeight

                property bool appeared: false
                property string grpAppName: modelData.appName
                property int grpCount: modelData.notifCount
                property bool isStacked: modelData.isStacked
                property var firstNotif: modelData.firstNotif
                property var notifItems: modelData.notifications
                property bool expanded: root.expandedAppName === grpAppName
                readonly property int expandedHeight: (notifItems.length * root.cardHeight) + (Math.max(0, notifItems.length - 1) * root.spacing)
                property real entryOffsetY: appeared ? 0 : -18

                opacity: appeared ? 1.0 : 0.0
                scale: appeared ? 1.0 : 0.92
                Component.onCompleted: appeared = true
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack } }
                Behavior on entryOffsetY { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }

                transform: Translate {
                    y: cardRoot.entryOffsetY
                }

                Item {
                    visible: isStacked
                    anchors.fill: parent

                    Repeater {
                        model: cardRoot.notifItems

                        Rectangle {
                            id: stackedCard
                            property var notification: modelData
                            readonly property int totalCount: cardRoot.notifItems.length
                            readonly property int reverseIndex: totalCount - 1 - index
                            readonly property int collapsedLayer: Math.min(2, reverseIndex)

                            width: cardRoot.width
                            height: root.cardHeight
                            radius: 22
                            color: "#000000"
                            visible: cardRoot.expanded || reverseIndex < 3
                            y: cardRoot.expanded ? index * (root.cardHeight + root.spacing) : collapsedLayer * 4
                            z: cardRoot.expanded ? (totalCount - index) : (100 - reverseIndex)
                            opacity: cardRoot.expanded ? 1.0 : (collapsedLayer === 0 ? 1.0 : collapsedLayer === 1 ? 0.82 : 0.64)
                            scale: cardRoot.expanded ? 1.0 : (collapsedLayer === 0 ? 1.0 : collapsedLayer === 1 ? 0.985 : 0.97)

                            Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                            Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                opacity: cardRoot.expanded || reverseIndex === 0 ? 1.0 : 0.0

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
                                        text: notification ? (notification.appName || "System") : ""
                                        color: "#ffffff"
                                        font { pixelSize: 11; weight: Font.DemiBold }
                                        opacity: 0.5
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    AppText {
                                        text: cardRoot.expanded
                                            ? (notification ? (notification.summary || notification.body || "") : "")
                                            : (grpCount + " notifications")
                                        color: "#ffffff"
                                        font { pixelSize: 14; weight: Font.Bold }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, stackMouse.containsMouse ? 0.15 : 0.0)

                                Behavior on border.color { ColorAnimation { duration: 180 } }
                            }

                            MouseArea {
                                id: stackMouse
                                anchors.fill: parent
                                enabled: cardRoot.expanded || reverseIndex === 0
                                hoverEnabled: enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!cardRoot.expanded) {
                                        root.toggleGroup(cardRoot.grpAppName)
                                    } else if (notification) {
                                        notification.dismiss()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !isStacked
                    anchors.fill: parent
                    radius: 22
                    color: "#000000"

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
                                text: firstNotif ? (firstNotif.appName || "System") : ""
                                color: "#ffffff"
                                font { pixelSize: 11; weight: Font.DemiBold }
                                opacity: 0.5
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            AppText {
                                text: firstNotif ? (firstNotif.summary || firstNotif.body || "") : ""
                                color: "#ffffff"
                                font { pixelSize: 14; weight: Font.Bold }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
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
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (firstNotif)
                                firstNotif.dismiss()
                        }
                    }
                }

                Rectangle {
                    visible: isStacked
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
                        onClicked: root.toggleGroup(cardRoot.grpAppName)
                    }
                }
            }
        }
    }
}
