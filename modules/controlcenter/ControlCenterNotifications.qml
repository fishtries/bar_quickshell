import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../components"
import "../../core"

ColumnLayout {
    id: notificationColumn

    spacing: 10

    property real gridContentHeight: 0
    property bool clearingNotifications: false
    readonly property int clearNotificationSwipeDuration: 280

    property real panelHeight: Math.max(160, gridContentHeight - notificationsHeader.implicitHeight - spacing)

    function clearNotificationsWithAnimation() {
        if (clearingNotifications || notificationList.count === 0)
            return;

        clearingNotifications = true;
        clearNotificationsTimer.restart();
    }

    Timer {
        id: clearNotificationsTimer
        interval: notificationColumn.clearNotificationSwipeDuration
        repeat: false
        onTriggered: {
            NotificationState.clearAll();
            clearNotificationsFallbackTimer.restart();
        }
    }

    Timer {
        id: clearNotificationsFallbackTimer
        interval: 260
        repeat: false
        onTriggered: notificationColumn.clearingNotifications = false
    }

    Item {
        id: notificationsHeader
        Layout.fillWidth: true
        height: 28

        AppText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.textPrimary
            font { pixelSize: 14; bold: true }
        }

        Rectangle {
            id: dndToggle
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 124
            implicitHeight: 28
            x: parent.width - implicitWidth - clearAllButton.opacity * (clearAllButton.implicitWidth + 8)

            radius: 14
            color: NotificationState.doNotDisturb ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.22) : (dndMouse.containsMouse ? Theme.bgHover : Theme.bgSubtle)
            border.color: NotificationState.doNotDisturb ? Theme.info : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 6
                spacing: 6

                AppText {
                    text: "Do Not Disturb"
                    color: NotificationState.doNotDisturb ? Theme.info : Theme.textSecondary
                    font { pixelSize: 9; weight: Font.DemiBold }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    id: dndTrack
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 16
                    radius: 8
                    color: NotificationState.doNotDisturb ? Theme.info : Theme.borderStrong
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        x: NotificationState.doNotDisturb ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: NotificationState.doNotDisturb ? Theme.bgElevated : Theme.textSecondary
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationState.doNotDisturb = !NotificationState.doNotDisturb
            }
        }

        Rectangle {
            id: clearAllButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            visible: notificationList.count > 0 || opacity > 0.01
            implicitWidth: 28
            implicitHeight: 28
            opacity: notificationList.count > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }

            layer.enabled: opacity > 0 && opacity < 1
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: Math.pow(1.0 - clearAllButton.opacity, 0.6)
            }

            radius: 14
            color: clearAllMouse.containsMouse ? Theme.bgHover : Theme.bgSubtle
            Behavior on color { ColorAnimation { duration: 150 } }

            AppIcon {
                anchors.centerIn: parent
                text: "󰆴"
                color: Theme.textPrimary
                font.pixelSize: 14
            }

            MouseArea {
                id: clearAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationColumn.clearNotificationsWithAnimation()
            }
        }
    }

    Item {
        visible: notificationList.count === 0 && !notificationColumn.clearingNotifications
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: notificationColumn.panelHeight

        Text {
            text: "No new notifications"
            color: Theme.textSecondary
            font.pixelSize: 13
            anchors.centerIn: parent
        }
    }

    ListView {
        id: notificationList
        visible: count > 0 || notificationColumn.clearingNotifications
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: notificationColumn.panelHeight
        clip: true
        spacing: 8
        model: NotificationState.activeNotifications

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { property: "x"; from: notificationList.width * 0.3; to: 0; duration: 400; easing.type: Easing.OutQuint }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
            NumberAnimation { property: "x"; to: -notificationList.width * 1.05; duration: 250; easing.type: Easing.InQuad }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { property: "opacity"; to: 1; duration: 200 }
        }

        delegate: Rectangle {
            id: notificationDelegate

            width: ListView.view ? ListView.view.width : 320
            height: notificationLayout.implicitHeight + 16
            radius: 12
            color: notificationMouse.containsMouse ? Theme.bgHover : Theme.bgSubtle
            border.color: notificationMouse.containsMouse ? Theme.borderSubtle : "transparent"
            border.width: 1

            property var notificationData: modelData
            property real clearOffsetX: notificationColumn.clearingNotifications ? -notificationList.width * 1.05 : 0

            transform: Translate {
                x: notificationDelegate.clearOffsetX
            }

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on clearOffsetX { NumberAnimation { duration: notificationColumn.clearNotificationSwipeDuration; easing.type: Easing.InCubic } }

            MouseArea {
                id: notificationMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (notificationData) {
                        notificationData.invokeDefaultAction();
                        notificationData.dismiss();
                    }
                }
            }

            ColumnLayout {
                id: notificationLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppText {
                        text: notificationData && notificationData.appName ? notificationData.appName : "System"
                        color: Theme.textSecondary
                        font { pixelSize: 12; weight: Font.DemiBold }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        color: dismissMouse.containsMouse ? Theme.bgHover : "transparent"
                        z: 1

                        AppText {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (notificationData) {
                                    notificationData.dismiss();
                                }
                            }
                        }
                    }
                }

                AppText {
                    Layout.fillWidth: true
                    text: notificationData && notificationData.summary ? notificationData.summary : "Notification"
                    color: Theme.textPrimary
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                AppText {
                    Layout.fillWidth: true
                    text: notificationData && notificationData.body ? notificationData.body : ""
                    visible: text !== ""
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.pixelSize: 12
                }
            }
        }
    }
}
