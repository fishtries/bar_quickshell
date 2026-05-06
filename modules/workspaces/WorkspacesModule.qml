import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../clock"
import QtQuick.Effects
import "../../components"
import "../../core"
import "../localsend" as LocalSend
import "../aside" as Aside

Rectangle {
    id: root
    
    // Morphing properties
    readonly property bool isIsland: IslandState.isActive
    readonly property bool isReminderIsland: IslandState.isReminder
    readonly property bool isLocalSendIsland: IslandState.isLocalSend
    readonly property bool isAsideIsland: IslandState.isAside
    readonly property var currentReminder: IslandState.reminderData
    readonly property var currentTransfer: IslandState.transferData
    readonly property bool isLocalSendConfirming: root.isLocalSendIsland && root.currentTransfer && root.currentTransfer.status === "confirming"
    property bool showCustomReminderPicker: false
    property var customReminderDate: new Date()
    property real islandContentBlur: 0.0
    property real islandContentOpacity: 1.0
    property var pendingIslandContentChange: null
    property bool displayReminderIsland: root.isReminderIsland
    property bool displayCustomReminderPicker: false
    readonly property bool isCustomReminderValid: root.customReminderDate && !isNaN(root.customReminderDate.getTime()) && root.customReminderDate.getTime() > Date.now()
    readonly property int reminderIslandWidth: root.showCustomReminderPicker ? 920 : 980
    readonly property int reminderIslandHeight: root.showCustomReminderPicker ? 440 : 136
    readonly property int asideIslandWidth: 760
    readonly property int asideIslandHeight: Aside.AsideState.hasConversation ? (Aside.AsideState.inputRequested ? 430 : 382) : (Aside.AsideState.inputRequested ? 146 : 96)
    
    color: isIsland ? "#000000" : Theme.localPanelForItem(root)
    radius: isIsland ? (isReminderIsland ? 26 : (isAsideIsland ? 28 : 18)) : Theme.radiusPanel
    z: isIsland ? 100 : 0
    property bool interactionEnabled: true
    readonly property real launcherAnchorX: width
    readonly property real launcherAnchorY: height * 0.5 + workspaceShift.y
    
    // Blur spike logic
    property real animBlur: 0.0
    onIsIslandChanged: {
        blurPulse.restart()
        if (!root.isIsland) {
            root.showCustomReminderPicker = false
            root.displayCustomReminderPicker = false
            root.displayReminderIsland = root.isReminderIsland
            root.pendingIslandContentChange = null
            root.islandContentBlur = 0.0
            root.islandContentOpacity = 1.0
        }
    }

    onIsReminderIslandChanged: {
        if (!root.isIsland) {
            root.displayReminderIsland = root.isReminderIsland
            if (!root.displayReminderIsland)
                root.displayCustomReminderPicker = false
            return
        }

        root.displayReminderIsland = root.isReminderIsland
        if (!root.displayReminderIsland) {
            root.displayCustomReminderPicker = false
            if (root.showCustomReminderPicker)
                root.showCustomReminderPicker = false
        }
    }

    onCurrentReminderChanged: {
        if (root.showCustomReminderPicker)
            root.showCustomReminderPicker = false

        root.customReminderDate = root.defaultCustomReminderDate()
    }

    onShowCustomReminderPickerChanged: {
        if (!root.isIsland || !root.displayReminderIsland) {
            root.displayCustomReminderPicker = root.showCustomReminderPicker
            if (root.displayCustomReminderPicker)
                root.syncCustomReminderCalendar(true)
            return
        }

        if (root.displayCustomReminderPicker === root.showCustomReminderPicker)
            return

        root.animateIslandContentChange(function() {
            root.displayCustomReminderPicker = root.showCustomReminderPicker
            if (root.displayCustomReminderPicker)
                root.syncCustomReminderCalendar(true)
        })
    }

    onCustomReminderDateChanged: root.syncCustomReminderCalendar(false)

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: 200; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: islandContentBlurPulse
        ParallelAnimation {
            NumberAnimation { target: root; property: "islandContentBlur"; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "islandContentOpacity"; to: 0.3; duration: 150; easing.type: Easing.OutQuint }
        }
        ScriptAction { script: root.applyPendingIslandContentChange() }
        ParallelAnimation {
            NumberAnimation { target: root; property: "islandContentBlur"; to: 0.0; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "islandContentOpacity"; to: 1.0; duration: 220; easing.type: Easing.OutQuad }
        }
    }

    function applyPendingIslandContentChange() {
        if (!root.pendingIslandContentChange)
            return

        let changeCallback = root.pendingIslandContentChange
        root.pendingIslandContentChange = null
        changeCallback()
    }

    function animateIslandContentChange(changeCallback) {
        if (!root.isIsland) {
            if (changeCallback)
                changeCallback()
            return
        }

        root.pendingIslandContentChange = changeCallback || null
        islandContentBlurPulse.restart()
    }

    implicitWidth: isIsland ? (isReminderIsland ? reminderIslandWidth : (isAsideIsland ? asideIslandWidth : (isLocalSendIsland ? (isLocalSendConfirming ? 680 : 560) : 600))) : (layout.implicitWidth + 12)
    implicitHeight: isIsland ? (isReminderIsland ? reminderIslandHeight : (isAsideIsland ? asideIslandHeight : 80)) : (layout.implicitHeight + 14)

    transform: Translate {
        id: workspaceShift
        y: {
            if (!root.isIsland) return 0;
            // Compensate for Row recentering: keep top edge fixed so expansion goes downward only
            var targetH = root.isReminderIsland ? root.reminderIslandHeight : (root.isAsideIsland ? root.asideIslandHeight : 80);
            return targetH / 2 - 24;
        }
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
    }

    // Smooth Transitions
    Behavior on color { ColorAnimation { duration: 400 } }
    Behavior on radius { NumberAnimation { duration: 400 } }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutElastic
            easing.amplitude: 0.1
            easing.period: 0.9
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutElastic
            easing.amplitude: 0.9
            easing.period: 0.8
        }
    }

    // Secondary Effects (Blur/Fade)
    layer.enabled: animBlur > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 32
        blur: root.animBlur
    }

    Connections {
        target: EventsState
        function onReminderTriggered(reminder) {
            if (reminder)
                IslandState.showReminder(reminder)
        }
    }

    Connections {
        target: IslandState
        function onReminderAutoActionRequested(reminder) {
            root.resolveReminderAction("snooze", reminder)
        }
    }

    Connections {
        target: Aside.AsideState
        function onInputRequestedChanged() {
            if (Aside.AsideState.inputRequested)
                asideInputFocusTimer.restart()
        }
    }

    onIsAsideIslandChanged: {
        if (root.isAsideIsland && Aside.AsideState.inputRequested)
            asideInputFocusTimer.restart()
    }

    Timer {
        id: asideInputFocusTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.isAsideIsland && Aside.AsideState.inputRequested) {
                asideInput.forceActiveFocus()
                asideInput.cursorPosition = asideInput.text.length
            }
        }
    }

    ListModel { id: wsModel }

    property var wsList: Hyprland.workspaces.values
    onWsListChanged: updateModel()

    function removeWorkspaceFromModel(id) {
        for (let i = 0; i < wsModel.count; i++) {
            if (wsModel.get(i).wsId === id && wsModel.get(i).wsIsRemoving) {
                wsModel.remove(i)
                break
            }
        }
    }

    function updateModel() {
        if (!wsList)
            return

        let workspaces = wsList.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
        
        for (let i = 0; i < wsModel.count; i++) {
            let currentId = wsModel.get(i).wsId
            if (!workspaces.find(w => w.id === currentId)) {
                if (wsModel.get(i).wsIsRemoving !== true)
                    wsModel.setProperty(i, "wsIsRemoving", true)
            }
        }
        
        for (let i = 0; i < workspaces.length; i++) {
            let ws = workspaces[i]
            let foundIndex = -1
            for (let j = 0; j < wsModel.count; j++) {
                if (wsModel.get(j).wsId === ws.id) {
                    foundIndex = j
                    break
                }
            }
            
            if (foundIndex === -1) {
                wsModel.insert(i, { wsId: ws.id, wsName: ws.name ? ws.name : "", wsIsRemoving: false })
            } else {
                if (wsModel.get(foundIndex).wsIsRemoving)
                    wsModel.setProperty(foundIndex, "wsIsRemoving", false)
                if (foundIndex !== i)
                    wsModel.move(foundIndex, i, 1)
                wsModel.setProperty(i, "wsName", ws.name ? ws.name : "")
            }
        }
    }

    function defaultCustomReminderDate() {
        let targetDate = new Date(Date.now() + (30 * 60000))
        targetDate.setSeconds(0, 0)

        let roundedMinutes = Math.ceil(targetDate.getMinutes() / 5) * 5
        if (roundedMinutes >= 60) {
            targetDate.setHours(targetDate.getHours() + 1)
            targetDate.setMinutes(0)
        } else {
            targetDate.setMinutes(roundedMinutes)
        }

        return targetDate
    }

    function setCustomReminderDate(dateObj) {
        if (!dateObj)
            return

        let nextDate = new Date(dateObj.getTime())
        nextDate.setSeconds(0, 0)
        root.customReminderDate = nextDate
        IslandState.restart()
    }

    function setCustomReminderDateFromKey(dateKeyStr) {
        if (!dateKeyStr)
            return

        let parts = dateKeyStr.split("-")
        if (parts.length !== 3)
            return

        let nextDate = new Date(root.customReminderDate.getTime())
        nextDate.setFullYear(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
        root.setCustomReminderDate(nextDate)
    }

    function syncCustomReminderCalendar(forceView) {
        if (!customReminderCalendar || !root.customReminderDate || isNaN(root.customReminderDate.getTime()))
            return

        let month = root.customReminderDate.getMonth() + 1
        let year = root.customReminderDate.getFullYear()

        customReminderCalendar.selectedDay = root.customReminderDate.getDate()
        customReminderCalendar.selectedMonth = month
        customReminderCalendar.selectedYear = year

        if (forceView === true) {
            customReminderCalendar.viewMonth = month
            customReminderCalendar.viewYear = year
        }
    }

    function changeCustomReminderDays(delta) {
        let nextDate = new Date(root.customReminderDate.getTime())
        nextDate.setDate(nextDate.getDate() + delta)
        root.setCustomReminderDate(nextDate)
    }

    function changeCustomReminderHours(delta) {
        let nextDate = new Date(root.customReminderDate.getTime())
        nextDate.setHours(nextDate.getHours() + delta)
        root.setCustomReminderDate(nextDate)
    }

    function changeCustomReminderMinutes(delta) {
        let nextDate = new Date(root.customReminderDate.getTime())
        nextDate.setMinutes(nextDate.getMinutes() + delta)
        root.setCustomReminderDate(nextDate)
    }

    function formatCustomReminderDate(dateObj) {
        if (!dateObj)
            return "Date"

        let now = new Date()
        let today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        let tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
        let selected = new Date(dateObj.getFullYear(), dateObj.getMonth(), dateObj.getDate())

        if (selected.getTime() === today.getTime())
            return "Today"
        if (selected.getTime() === tomorrow.getTime())
            return "Tomorrow"

        return Qt.formatDate(dateObj, "ddd, d MMM")
    }

    function formatCustomReminderSummary(dateObj) {
        if (!dateObj)
            return ""

        return `Will remind on ${Qt.formatDate(dateObj, "dddd, d MMMM")} at ${Qt.formatTime(dateObj, "HH:mm")}`
    }

    function openCustomReminderPicker() {
        root.showCustomReminderPicker = true
        root.customReminderDate = root.defaultCustomReminderDate()
        IslandState.restart()
    }

    function closeCustomReminderPicker() {
        root.showCustomReminderPicker = false
        IslandState.restart()
    }

    function applyCustomReminder() {
        if (!root.currentReminder || !root.isCustomReminderValid || EventsState.reminderActionBusy)
            return

        let scheduled = EventsState.scheduleReminder(root.currentReminder, root.customReminderDate)
        if (!scheduled)
            return

        root.showCustomReminderPicker = false
        IslandState.hide()
    }

    function formatReminderTime(reminder) {
        if (!reminder || !reminder.time || reminder.time.length === 0)
            return "No time"

        return `At ${reminder.time}`
    }

    function resolveReminderAction(action, reminderOverride) {
        let reminder = reminderOverride || IslandState.reminderData
        if (!reminder || EventsState.reminderActionBusy)
            return

        if (action === "custom") {
            root.openCustomReminderPicker()
            return
        }

        if (action === "snooze") {
            EventsState.snoozeReminder(reminder)
        } else if (action === "tomorrow") {
            EventsState.remindTomorrow(reminder)
        } else if (action === "complete") {
            EventsState.completeReminder(reminder)
        }

        IslandState.hide()
    }

    function clampTransferProgress() {
        let transfer = root.currentTransfer
        if (!transfer)
            return 0

        return Math.max(0, Math.min(1, Number(transfer.progress || 0)))
    }

    function formatTransferBytes(value) {
        let bytes = Number(value || 0)
        if (bytes < 1024)
            return `${Math.round(bytes)} B`
        if (bytes < 1024 * 1024)
            return `${(bytes / 1024).toFixed(1)} KB`
        if (bytes < 1024 * 1024 * 1024)
            return `${(bytes / 1024 / 1024).toFixed(1)} MB`
        return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
    }

    function transferTitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return "LocalSend"

        if (transfer.status === "finished")
            return transfer.direction === "receive" ? "Received" : "Sent"
        if (transfer.status === "error")
            return "LocalSend failed"
        if (transfer.status === "preparing")
            return "Preparing transfer"

        return transfer.direction === "receive" ? "Receiving" : "Sending"
    }

    function transferSubtitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return ""

        if (transfer.status === "error")
            return transfer.message || "Transfer failed"

        let peer = transfer.peer || "Device"
        let file = transfer.fileName ? ` · ${transfer.fileName}` : ""
        let bytes = transfer.totalBytes > 0 ? ` · ${root.formatTransferBytes(transfer.sentBytes)} / ${root.formatTransferBytes(transfer.totalBytes)}` : ""
        return `${peer}${file}${bytes}`
    }

    function incomingConfirmationSubtitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return ""

        let count = Number(transfer.fileCount || 0)
        let files = count === 1 ? "1 file" : `${count} files`
        let bytes = transfer.totalBytes > 0 ? ` · ${root.formatTransferBytes(transfer.totalBytes)}` : ""
        return `${transfer.peer || "Device"} wants to send ${files}${bytes}`
    }

    Component.onCompleted: {
        updateModel()
        LocalSend.LocalSendState.startReceiver()
        if (EventsState.activeReminder)
            IslandState.showReminder(EventsState.activeReminder)
    }

    // ─── Content 1: Workspaces ──────────────────────────────────────
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 0
        opacity: root.isIsland ? 0.0 : 1.0
        scale: root.isIsland ? 0.8 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 500 } }

        Repeater {
            model: wsModel

            Item {
                property int wId: wsId
                property string wName: wsName
                property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wId
                property bool isLoaded: false
                property bool isRemoving: wsIsRemoving !== undefined ? wsIsRemoving : false
                property bool shouldShow: isLoaded && !isRemoving
                property real targetWidth: shouldShow ? (isActive ? 40 + 8 : 28 + 8) : 0

                Component.onCompleted: isLoaded = true
                Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                implicitWidth: Math.max(0, targetWidth)
                implicitHeight: 28

                Timer {
                    running: isRemoving
                    interval: 400
                    onTriggered: root.removeWorkspaceFromModel(wId)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.targetWidth - 6)
                    height: 32
                    radius: 15
                    opacity: shouldShow ? 1.0 : 0.0
                    color: isActive ? Theme.localHoverForItem(parent) : "transparent"

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on color { ColorAnimation { duration: 300 } }

                    AppText {
                        anchors.centerIn: parent
                        text: wName !== "" ? wName : wId
                        color: isActive ? Theme.foregroundForItem(parent) : Theme.secondaryForegroundForItem(parent)
                        font { pixelSize: 14; bold: true }
                        scale: shouldShow ? (isActive ? 1.25 : 1.0) : 0.0
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.interactionEnabled && !root.isIsland
                        onClicked: Hyprland.dispatch("workspace " + wId)
                    }
                }
            }
        }
    }

    // ─── Content 2: Island Overlay ──────────────────────────────────
    RowLayout {
        id: islandContent
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12
        
        opacity: root.isIsland ? 1.0 : 0.0
        scale: root.isIsland ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
        layer.enabled: root.isIsland || root.islandContentBlur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 28
            blur: root.islandContentBlur
        }

        ColumnLayout {
            visible: root.displayReminderIsland
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                AppIcon {
                    text: "\uf017"
                    font.pixelSize: 20
                    color: Theme.warning
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    AppText {
                        Layout.fillWidth: true
                        text: root.currentReminder ? root.currentReminder.title : "Reminder"
                        color: "#ffffff"
                        font { pixelSize: 15; weight: Font.Bold }
                        elide: Text.ElideRight
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.formatReminderTime(root.currentReminder)
                        color: "#cccccc"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                visible: !root.displayCustomReminderPicker
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: snoozeMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (snoozeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, snoozeMouse.containsMouse ? 0.16 : 0.08)
                    opacity: EventsState.reminderActionBusy ? 0.45 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    AppText {
                        anchors.centerIn: parent
                        text: "Remind in 5 min"
                        color: "#ffffff"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: snoozeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !EventsState.reminderActionBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resolveReminderAction("snooze")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: customMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, customMouse.containsMouse ? 0.16 : 0.08)
                    opacity: EventsState.reminderActionBusy ? 0.45 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    AppText {
                        anchors.centerIn: parent
                        text: "Remind in..."
                        color: "#ffffff"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: customMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !EventsState.reminderActionBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resolveReminderAction("custom")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: tomorrowMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (tomorrowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, tomorrowMouse.containsMouse ? 0.16 : 0.08)
                    opacity: EventsState.reminderActionBusy ? 0.45 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    AppText {
                        anchors.centerIn: parent
                        text: "Remind tomorrow"
                        color: "#ffffff"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: tomorrowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !EventsState.reminderActionBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resolveReminderAction("tomorrow")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: completeMouse.pressed ? Qt.rgba(1, 0.35, 0.35, 0.24) : (completeMouse.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: completeMouse.containsMouse ? Qt.rgba(1, 0.45, 0.45, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                    opacity: EventsState.reminderActionBusy ? 0.45 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    AppText {
                        anchors.centerIn: parent
                        text: "Mark as complete"
                        color: "#ffffff"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: completeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !EventsState.reminderActionBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resolveReminderAction("complete")
                    }
                }
            }

            RowLayout {
                visible: root.displayCustomReminderPicker
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 292
                    Layout.fillHeight: true
                    radius: 22
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    CalendarModule {
                        id: customReminderCalendar
                        anchors.fill: parent
                        anchors.margins: 12
                        onDaySelected: function(dateKey, hasEvents) {
                            root.setCustomReminderDateFromKey(dateKey)
                        }
                        onViewMonthChanged: IslandState.restart()
                        onViewYearChanged: IslandState.restart()
                        Component.onCompleted: root.syncCustomReminderCalendar(true)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    AppText {
                        Layout.fillWidth: true
                        text: root.formatCustomReminderSummary(root.customReminderDate)
                        color: root.isCustomReminderValid ? "#cccccc" : Theme.error
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    AppText {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        text: Qt.formatTime(root.customReminderDate, "HH:mm")
                        color: "#ffffff"
                        font { pixelSize: 42; weight: Font.Bold }
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 16
                                    color: Qt.rgba(1, 1, 1, 0.06)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        AppText {
                                            text: "Hour"
                                            color: "#999999"
                                            font.pixelSize: 10
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 6

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: customHourPrevMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customHourPrevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                                                AppText {
                                                    anchors.centerIn: parent
                                                    text: "−"
                                                    color: "#ffffff"
                                                    font { pixelSize: 16; weight: Font.Bold }
                                                }

                                                MouseArea {
                                                    id: customHourPrevMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: !EventsState.reminderActionBusy
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeCustomReminderHours(-1)
                                                }
                                            }

                                            AppText {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: Qt.formatTime(root.customReminderDate, "HH")
                                                color: "#ffffff"
                                                font { pixelSize: 28; weight: Font.Bold }
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: customHourNextMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customHourNextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                                                AppText {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: "#ffffff"
                                                    font { pixelSize: 16; weight: Font.Bold }
                                                }

                                                MouseArea {
                                                    id: customHourNextMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: !EventsState.reminderActionBusy
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeCustomReminderHours(1)
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 16
                                    color: Qt.rgba(1, 1, 1, 0.06)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 4

                                        AppText {
                                            text: "Minute"
                                            color: "#999999"
                                            font.pixelSize: 10
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 6

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: customMinutePrevMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customMinutePrevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                                                AppText {
                                                    anchors.centerIn: parent
                                                    text: "−"
                                                    color: "#ffffff"
                                                    font { pixelSize: 16; weight: Font.Bold }
                                                }

                                                MouseArea {
                                                    id: customMinutePrevMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: !EventsState.reminderActionBusy
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeCustomReminderMinutes(-5)
                                                }
                                            }

                                            AppText {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                text: Qt.formatTime(root.customReminderDate, "mm")
                                                color: "#ffffff"
                                                font { pixelSize: 28; weight: Font.Bold }
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 18
                                                color: customMinuteNextMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customMinuteNextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                                                AppText {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: "#ffffff"
                                                    font { pixelSize: 16; weight: Font.Bold }
                                                }

                                                MouseArea {
                                                    id: customMinuteNextMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: !EventsState.reminderActionBusy
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.changeCustomReminderMinutes(5)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 18
                            color: customBackMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : (customBackMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, customBackMouse.containsMouse ? 0.16 : 0.08)

                            AppText {
                                anchors.centerIn: parent
                                text: "Back"
                                color: "#ffffff"
                                font { pixelSize: 12; weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: customBackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !EventsState.reminderActionBusy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeCustomReminderPicker()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 18
                            color: customApplyMouse.pressed ? Qt.rgba(0.33, 0.8, 1, 0.28) : (customApplyMouse.containsMouse ? Qt.rgba(0.33, 0.8, 1, 0.18) : Qt.rgba(0.33, 0.8, 1, 0.12))
                            border.width: 1
                            border.color: Qt.rgba(0.33, 0.8, 1, customApplyMouse.containsMouse ? 0.34 : 0.2)
                            opacity: root.isCustomReminderValid && !EventsState.reminderActionBusy ? 1.0 : 0.45

                            AppText {
                                anchors.centerIn: parent
                                text: "Set reminder"
                                color: "#ffffff"
                                font { pixelSize: 12; weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: customApplyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.isCustomReminderValid && !EventsState.reminderActionBusy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyCustomReminder()
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: root.isAsideIsland
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 16
                    color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.35)

                    AppIcon {
                        anchors.centerIn: parent
                        text: Aside.AsideState.phase === "listening" ? "󰍬" : "󰚩"
                        font.pixelSize: 20
                        color: Theme.info
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 190
                    spacing: 2

                    AppText {
                        Layout.fillWidth: true
                        text: "Aside"
                        color: "#ffffff"
                        font { pixelSize: 15; weight: Font.Bold }
                        elide: Text.ElideRight
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: Aside.AsideState.shortModelName + " · " + Aside.AsideState.statusText
                        color: Aside.AsideState.errorMessage !== "" ? Theme.warning : "#aaaaaa"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Aside.AsideParticleVisualizer {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    level: Aside.AsideState.phase === "listening" ? Math.max(Aside.AsideState.audioLevel, 0.06) : (Aside.AsideState.isBusy ? 0.18 : 0.02)
                    active: root.isAsideIsland && (Aside.AsideState.phase === "listening" || Aside.AsideState.isBusy)
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideNewMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, asideNewMouse.containsMouse ? 0.20 : 0.10)

                    AppIcon {
                        anchors.centerIn: parent
                        text: "\uf067"
                        font.pixelSize: 13
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: asideNewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.newConversation()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideMicMouse.containsMouse || Aside.AsideState.phase === "listening" ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, asideMicMouse.containsMouse || Aside.AsideState.phase === "listening" ? 0.40 : 0.16)

                    AppIcon {
                        anchors.centerIn: parent
                        text: "󰍬"
                        font.pixelSize: 14
                        color: Aside.AsideState.phase === "listening" ? Theme.info : "#ffffff"
                    }

                    MouseArea {
                        id: asideMicMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.startMic()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideCloseMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: asideCloseMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.36) : Qt.rgba(1, 1, 1, 0.10)

                    AppIcon {
                        anchors.centerIn: parent
                        text: Aside.AsideState.isBusy ? "󰓛" : "\uf00d"
                        font.pixelSize: 13
                        color: asideCloseMouse.containsMouse ? Theme.error : "#ffffff"
                    }

                    MouseArea {
                        id: asideCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Aside.AsideState.isBusy)
                                Aside.AsideState.cancel()
                            else
                                Aside.AsideState.closeIsland()
                        }
                    }
                }
            }

            Flickable {
                id: asideMessagesFlick
                visible: Aside.AsideState.hasConversation
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: asideMessageStack.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                onHeightChanged: contentY = Math.max(0, contentHeight - height)

                Column {
                    id: asideMessageStack
                    width: asideMessagesFlick.width
                    spacing: 8

                    Repeater {
                        model: Aside.AsideState.messagesModel

                        delegate: Rectangle {
                            readonly property bool shouldDisplay: index >= Math.max(0, Aside.AsideState.messagesModel.count - 2)

                            visible: shouldDisplay
                            width: asideMessageStack.width
                            height: shouldDisplay ? Math.max(50, asideRoleLabel.implicitHeight + asideMessageText.implicitHeight + 20) : 0
                            radius: 18
                            color: model.role === "user" ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.13) : Qt.rgba(1, 1, 1, 0.075)
                            border.width: 1
                            border.color: model.role === "user" ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.30) : Qt.rgba(1, 1, 1, 0.10)

                            AppText {
                                id: asideRoleLabel
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                text: model.role === "user" ? "You" : "Aside"
                                color: model.role === "user" ? Theme.info : "#ffffff"
                                font { pixelSize: 11; weight: Font.Bold }
                                elide: Text.ElideRight
                            }

                            TextEdit {
                                id: asideMessageText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: asideRoleLabel.bottom
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 4
                                text: model.text === "" && model.role === "assistant" && Aside.AsideState.isBusy ? "…" : model.text
                                color: "#eeeeee"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                selectByMouse: true
                                clip: false
                                selectedTextColor: "#000000"
                                selectionColor: Theme.info
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: Aside.AsideState.inputRequested
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 42 : 0
                radius: 21
                color: asideInput.activeFocus ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                border.color: asideInput.activeFocus ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.48) : Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 8

                    TextInput {
                        id: asideInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.family: Theme.fontPrimary
                        font.pixelSize: 14
                        enabled: Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                        selectByMouse: true
                        clip: true
                        Keys.onEscapePressed: Aside.AsideState.closeIsland()
                        Keys.onReturnPressed: {
                            let value = asideInput.text.trim()
                            if (value !== "") {
                                asideInput.text = ""
                                Aside.AsideState.sendQuery(value)
                            }
                        }
                        Keys.onEnterPressed: {
                            let value = asideInput.text.trim()
                            if (value !== "") {
                                asideInput.text = ""
                                Aside.AsideState.sendQuery(value)
                            }
                        }

                        AppText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Aside.AsideState.daemonAvailable ? "Ask Aside…" : "aside daemon is offline"
                            color: "#777777"
                            font: asideInput.font
                            enabled: false
                            visible: !asideInput.text && !asideInput.preeditText
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: asideSendMouse.containsMouse ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.30) : Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.16)
                        opacity: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy ? 1.0 : 0.45

                        AppIcon {
                            anchors.centerIn: parent
                            text: "󰒊"
                            font.pixelSize: 14
                            color: Theme.info
                        }

                        MouseArea {
                            id: asideSendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let value = asideInput.text.trim()
                                if (value !== "") {
                                    asideInput.text = ""
                                    Aside.AsideState.sendQuery(value)
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: !root.displayReminderIsland && !root.isAsideIsland && root.isLocalSendIsland && !root.isLocalSendConfirming
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppIcon {
                text: root.currentTransfer && root.currentTransfer.status === "error" ? "\uf071" : "\uf0ec"
                font.pixelSize: 20
                color: root.currentTransfer && root.currentTransfer.status === "error" ? Theme.error : Theme.info
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    AppText {
                        text: root.transferTitle()
                        color: "#ffffff"
                        font { pixelSize: 14; weight: Font.Bold }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    AppText {
                        text: `${Math.round(root.clampTransferProgress() * 100)}%`
                        color: "#cccccc"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * root.clampTransferProgress()
                        radius: 3
                        color: root.currentTransfer && root.currentTransfer.status === "error" ? Theme.error : Theme.info
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    }
                }

                AppText {
                    text: root.transferSubtitle()
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
        }

        RowLayout {
            visible: !root.displayReminderIsland && !root.isAsideIsland && root.isLocalSendConfirming
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppIcon {
                text: "\uf019"
                font.pixelSize: 20
                color: Theme.info
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                AppText {
                    text: "Accept incoming files?"
                    color: "#ffffff"
                    font { pixelSize: 14; weight: Font.Bold }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                AppText {
                    text: root.incomingConfirmationSubtitle()
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 34
                radius: 17
                color: rejectReceiveMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.22) : Qt.rgba(1, 0.3, 0.3, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 0.3, 0.3, rejectReceiveMouse.containsMouse ? 0.4 : 0.2)

                AppText {
                    anchors.centerIn: parent
                    text: "Reject"
                    color: "#ffffff"
                    font { pixelSize: 12; weight: Font.DemiBold }
                }

                MouseArea {
                    id: rejectReceiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.LocalSendState.confirmReceive(false)
                }
            }

            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 34
                radius: 17
                color: acceptReceiveMouse.containsMouse ? Qt.rgba(0.4, 1, 0.55, 0.22) : Qt.rgba(0.4, 1, 0.55, 0.12)
                border.width: 1
                border.color: Qt.rgba(0.4, 1, 0.55, acceptReceiveMouse.containsMouse ? 0.4 : 0.2)

                AppText {
                    anchors.centerIn: parent
                    text: "Accept"
                    color: "#ffffff"
                    font { pixelSize: 12; weight: Font.DemiBold }
                }

                MouseArea {
                    id: acceptReceiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.LocalSendState.confirmReceive(true)
                }
            }
        }

        RowLayout {
            visible: !root.displayReminderIsland && !root.isAsideIsland && !root.isLocalSendIsland
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppIcon {
                text: IslandState.sourceModule === "screenshot" ? "\udb81\udcf7" : "\uf00c"
                font.pixelSize: 18
                color: Theme.success
            }

            AppText {
                text: IslandState.sourceModule === "screenshot" ? "Screenshot Saved" : "Success"
                color: "#ffffff"
                font { pixelSize: 14; weight: Font.Medium }
                Layout.fillWidth: true
            }
        }
    }
}
