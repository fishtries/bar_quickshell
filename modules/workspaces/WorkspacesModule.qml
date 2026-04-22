import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../clock"
import QtQuick.Effects
import "../../components"
import "../../core"

Rectangle {
    id: root
    
    // Morphing properties
    readonly property bool isIsland: IslandState.isActive
    readonly property bool isReminderIsland: IslandState.isReminder
    readonly property var currentReminder: IslandState.reminderData
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
    
    color: isIsland ? "#000000" : Theme.bgPanel
    radius: isIsland ? (isReminderIsland ? 26 : 18) : Theme.radiusPanel
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

    implicitWidth: isIsland ? (isReminderIsland ? reminderIslandWidth : 600) : (layout.implicitWidth + 12)
    implicitHeight: isIsland ? (isReminderIsland ? reminderIslandHeight : 80) : (layout.implicitHeight + 14)

    transform: Translate {
        id: workspaceShift
        y: {
            if (!root.isIsland) return 0;
            // Compensate for Row recentering: keep top edge fixed so expansion goes downward only
            var targetH = root.isReminderIsland ? root.reminderIslandHeight : 80;
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

    Component.onCompleted: {
        updateModel()
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
                    color: isActive ? Theme.bgActive : "transparent"

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on color { ColorAnimation { duration: 300 } }

                    AppText {
                        anchors.centerIn: parent
                        text: wName !== "" ? wName : wId
                        color: Theme.textPrimary
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

        RowLayout {
            visible: !root.displayReminderIsland
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
