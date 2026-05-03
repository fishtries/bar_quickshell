import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
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
    property string replyText: ""
    property bool replyKeyboardRequested: false
    property bool replyHovered: false

    property var displayedNotification: null
    property real notifBlur: 0.0
    readonly property bool replyVisible: notifExpanded && canReplyToNotification(displayedNotification)
    readonly property bool needsKeyboard: replyVisible && replyKeyboardRequested

    readonly property bool isDragging: notifSwipe.isDragging
    readonly property real visualOffsetX: notifSwipe.visualOffsetX
    readonly property real visualOffsetY: notifSwipe.visualOffsetY
    readonly property real dragOpacity: notifSwipe.dragOpacity

    signal dismissRequested()
    signal autoHideDismissRequested()
    signal hideRequested()

    onIsDraggingChanged: {
        if (!isDragging && root.isNotifIsland && root.currentNotification && !pointerInsideIsland())
            collapseDelayTimer.restart()
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
        replyText = ""
        replyKeyboardRequested = false
        replyHovered = false
    }

    function pointerInsideIsland() {
        return islandMouseArea.containsMouse || replyHovered || replyKeyboardRequested
    }

    function collapseIfPointerOutside() {
        if (root.isDragging || !root.isNotifIsland || !root.currentNotification || pointerInsideIsland())
            return

        notifHovered = false
        hoverExpandTimer.stop()
        hoverProgress = 0.0
        notifExpanded = false
        restartAutoHide()
    }

    function notificationAppIconSource(notification) {
        if (!notification)
            return ""

        const appIcon = ((notification.appIcon || notification.icon || "") + "")
        const desktopEntry = ((notification.desktopEntry || "") + "")
        const appName = ((notification.appName || "") + "")
        const lookupLabel = (appIcon + " " + desktopEntry + " " + appName).toLowerCase()

        if (lookupLabel.indexOf("telegram") !== -1)
            return "../../assets/app-icons/telegram.png"
        if (appIcon !== "") {
            if (appIcon.indexOf("/") === 0 || appIcon.indexOf("file:") === 0 || appIcon.indexOf("image:") === 0)
                return appIcon
            return "image://icon/" + appIcon
        }
        if (desktopEntry !== "")
            return "image://icon/" + desktopEntry
        if (appName !== "")
            return "image://icon/" + appName.toLowerCase()

        return ""
    }

    function notificationAppInitial(notification) {
        const label = notification ? (((notification.appName || notification.desktopEntry || "N") + "").trim()) : "N"
        return label.length > 0 ? label.charAt(0).toUpperCase() : "N"
    }

    function isTelegramDesktopNotification(notification) {
        if (!notification)
            return false

        const label = (((notification.appName || "") + " " + (notification.desktopEntry || "") + " " + (notification.appIcon || "")) + "").toLowerCase()
        return label.indexOf("telegram") !== -1
    }

    function canReplyToNotification(notification) {
        return !!notification && isTelegramDesktopNotification(notification) && notification.hasInlineReply && typeof notification.sendInlineReply === "function"
    }

    function activateNotification(notification) {
        if (!notification)
            return

        try {
            if (typeof notification.invokeDefaultAction === "function")
                notification.invokeDefaultAction()
        } catch (e) {
        }
    }

    function submitInlineReply() {
        const notification = root.displayedNotification
        const reply = root.replyText.trim()

        if (reply === "" || !canReplyToNotification(notification))
            return

        try {
            notification.sendInlineReply(reply)
            root.replyText = ""
            root.notifInteracted = true
            root.dismissRequested()
        } catch (e) {
        }
    }

    onReplyVisibleChanged: {
        if (!replyVisible)
            replyKeyboardRequested = false
    }

    onCurrentNotificationChanged: {
        replyText = ""
        replyKeyboardRequested = false
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
            // Time expired — just move to next unseen or hide island.
            // No .dismiss() here; notification stays in Control Center.
            if (!root.notifInteracted) {
                root.hideRequested()
            } else {
                root.autoHideDismissRequested()
            }
        }
    }

    Timer {
        id: collapseDelayTimer
        interval: 120
        repeat: false
        onTriggered: root.collapseIfPointerOutside()
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

                Rectangle {
                    id: compactAppIconBadge
                    readonly property string iconSource: root.notificationAppIconSource(root.displayedNotification)
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        id: compactAppImage
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: compactAppIconBadge.iconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: compactAppIconBadge.iconSource !== "" && status !== Image.Error
                    }

                    AppText {
                        anchors.centerIn: parent
                        text: root.notificationAppInitial(root.displayedNotification)
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        visible: compactAppIconBadge.iconSource === "" || compactAppImage.status === Image.Error
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: compactTextCol.implicitHeight
                    layer.enabled: root.notifBlur > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: AnimationConfig.blurMaxLight
                        blur: root.notifBlur
                    }
                    ColumnLayout {
                        id: compactTextCol
                        anchors.fill: parent
                        spacing: 1

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.summary || "") : ""
                            color: "#ffffff"
                            font { pixelSize: 14; weight: Font.DemiBold }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.body || "") : ""
                            color: "#cccccc"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                        }
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
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                opacity: root.notifExpanded ? 1.0 : 0.0
                scale: root.notifExpanded ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationNormal; easing.type: AnimationConfig.easingDefaultOut } }
                Behavior on scale { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingOvershootOut } }

                Rectangle {
                    id: expandedAppIconBadge
                    readonly property string iconSource: root.notificationAppIconSource(root.displayedNotification)
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        id: expandedAppImage
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: expandedAppIconBadge.iconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: expandedAppIconBadge.iconSource !== "" && status !== Image.Error
                    }

                    AppText {
                        anchors.centerIn: parent
                        text: root.notificationAppInitial(root.displayedNotification)
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        visible: expandedAppIconBadge.iconSource === "" || expandedAppImage.status === Image.Error
                    }
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
                            font { pixelSize: 14; weight: Font.Bold }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        AppText {
                            text: root.displayedNotification ? (root.displayedNotification.body || "") : ""
                            color: "#cccccc"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            Layout.fillWidth: true
                            visible: text !== ""
                        }

                        Rectangle {
                            id: replyBox
                            readonly property bool canSubmit: root.replyText.trim() !== ""
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            Layout.topMargin: 6
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: replyInput.activeFocus ? Theme.info : Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            visible: root.replyVisible
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: AnimationConfig.durationQuick } }

                            HoverHandler {
                                id: replyHover
                                onHoveredChanged: {
                                    root.replyHovered = hovered
                                    root.replyKeyboardRequested = hovered || replyInput.activeFocus
                                    if (hovered) {
                                        collapseDelayTimer.stop()
                                        root.stopAutoHide()
                                    } else if (!replyInput.activeFocus) {
                                        collapseDelayTimer.restart()
                                    }
                                }
                            }

                            Timer {
                                id: replyFocusTimer
                                interval: 1
                                repeat: false
                                onTriggered: replyInput.forceActiveFocus()
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.IBeamCursor
                                z: 0
                                onClicked: {
                                    root.replyKeyboardRequested = true
                                    replyFocusTimer.restart()
                                }
                            }

                            TextInput {
                                id: replyInput
                                anchors.left: parent.left
                                anchors.right: sendReplyButton.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                text: root.replyText
                                color: "#ffffff"
                                selectionColor: Theme.info
                                selectedTextColor: "#ffffff"
                                font.pixelSize: 11
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                z: 1
                                onTextEdited: root.replyText = text
                                onActiveFocusChanged: {
                                    root.replyKeyboardRequested = activeFocus || replyHover.hovered
                                    if (activeFocus) {
                                        collapseDelayTimer.stop()
                                        root.notifInteracted = true
                                        root.stopAutoHide()
                                    } else if (!replyHover.hovered) {
                                        collapseDelayTimer.restart()
                                    }
                                }
                                Keys.onReturnPressed: root.submitInlineReply()
                                Keys.onEnterPressed: root.submitInlineReply()
                            }

                            AppText {
                                anchors.left: replyInput.left
                                anchors.verticalCenter: replyInput.verticalCenter
                                text: root.displayedNotification && root.displayedNotification.inlineReplyPlaceholder ? root.displayedNotification.inlineReplyPlaceholder : "Ответить в Telegram…"
                                color: "#cccccc"
                                opacity: 0.55
                                font.pixelSize: 11
                                visible: root.replyText === "" && !replyInput.activeFocus
                                z: 1
                            }

                            Rectangle {
                                id: sendReplyButton
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 22
                                radius: 8
                                color: replyBox.canSubmit ? Theme.info : Qt.rgba(1, 1, 1, 0.08)
                                z: 2

                                Behavior on color { ColorAnimation { duration: AnimationConfig.durationQuick } }

                                AppText {
                                    anchors.centerIn: parent
                                    text: "↵"
                                    color: replyBox.canSubmit ? "#ffffff" : "#888888"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: replyBox.canSubmit
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.submitInlineReply()
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: islandMouseArea
                anchors.fill: parent
                visible: root.isNotifIsland
                hoverEnabled: true
                z: -1

                onEntered: {
                    if (!root.isDragging) {
                        collapseDelayTimer.stop()
                        root.notifHovered = true
                        root.hoverProgress = 0.0
                        hoverExpandTimer.start()
                        root.stopAutoHide()
                    }
                }

                onExited: {
                    if (!root.isDragging)
                        collapseDelayTimer.restart()
                }

                onClicked: function(mouse) {
                    if (!root.isDragging) {
                        root.notifInteracted = true
                        root.activateNotification(root.displayedNotification || root.currentNotification)
                        root.dismissRequested()
                    }
                }
            }
        }
    }
}
