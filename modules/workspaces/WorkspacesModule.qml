import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../clock"
import QtQuick.Effects
import "../../components"
import "../../core"
import "../localsend" as LocalSend
import "islands"

Rectangle {
    id: root
    
    // Morphing properties
    readonly property bool isIsland: IslandState.isActive
    readonly property bool isReminderIsland: IslandState.isReminder
    readonly property bool isLocalSendIsland: IslandState.isLocalSend
    readonly property bool isAsideIsland: IslandState.isAside
    
    color: isIsland ? "#000000" : Theme.localPanelForItem(root)
    radius: isIsland ? (isReminderIsland ? reminderModule.requestedRadius : (isAsideIsland ? asideModule.requestedRadius : (isLocalSendIsland ? localSendModule.requestedRadius : 18))) : Theme.radiusPanel
    border.width: 0
    border.color: "transparent"
    z: isIsland ? 100 : 0
    property bool interactionEnabled: true
    readonly property real launcherAnchorX: width
    readonly property real launcherAnchorY: height * 0.5 + workspaceShift.y
    
    // Blur spike logic
    property real animBlur: 0.0
    onIsIslandChanged: {
        blurPulse.restart()
        if (!root.isIsland) {
            reminderModule.showCustomReminderPicker = false
            reminderModule.displayCustomReminderPicker = false
            reminderModule.displayReminderIsland = root.isReminderIsland
            reminderModule.pendingIslandContentChange = null
            reminderModule.islandContentBlur = 0.0
            reminderModule.islandContentOpacity = 1.0
        }
    }

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: 200; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
    }

    implicitWidth: isIsland ? (isReminderIsland ? reminderModule.requestedWidth : (isAsideIsland ? asideModule.requestedWidth : (isLocalSendIsland ? localSendModule.requestedWidth : 600))) : (layout.implicitWidth + 12)
    implicitHeight: isIsland ? (isReminderIsland ? reminderModule.requestedHeight : (isAsideIsland ? asideModule.requestedHeight : (isLocalSendIsland ? localSendModule.requestedHeight : 80))) : (layout.implicitHeight + 14)

    transform: Translate {
        id: workspaceShift
        y: {
            if (!root.isIsland) return 0;
            // Compensate for Row recentering: keep top edge fixed so expansion goes downward only
            var targetH = root.isReminderIsland ? reminderModule.requestedHeight : (root.isAsideIsland ? asideModule.requestedHeight : (root.isLocalSendIsland ? localSendModule.requestedHeight : 80));
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
            reminderModule.resolveReminderAction("snooze", reminder)
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

    AsideIslandContent {
        id: asideModule
        anchors.fill: parent
        opacity: root.isAsideIsland ? 1 : 0
        visible: opacity > 0
    }

    // ─── Content 2: Island Overlay ──────────────────────────────────
    ReminderIslandContent {
        id: reminderModule
        anchors.fill: parent
        opacity: root.isReminderIsland ? 1 : 0
        visible: opacity > 0
    }

    LocalSendIslandContent {
        id: localSendModule
        anchors.fill: parent
        opacity: root.isLocalSendIsland ? 1 : 0
        visible: opacity > 0
    }

    // Success UI (remains inline - not part of LocalSend or Reminder)
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        opacity: root.isIsland && !root.isReminderIsland && !root.isAsideIsland && !root.isLocalSendIsland ? 1.0 : 0.0
        scale: root.isIsland && !root.isReminderIsland && !root.isAsideIsland && !root.isLocalSendIsland ? 1.0 : 0.6
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 28
            blur: 0.0
        }

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
