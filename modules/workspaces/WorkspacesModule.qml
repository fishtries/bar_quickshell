import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import QtQuick.Effects
import "../../components"
import "../../core"

Rectangle {
    id: root
    
    // Morphing properties
    readonly property bool isIsland: IslandState.isActive
    readonly property bool isReminderIsland: IslandState.isReminder
    readonly property var currentReminder: IslandState.reminderData
    readonly property int reminderIslandWidth: 780
    readonly property int reminderIslandHeight: 118
    
    color: isIsland ? "#000000" : Theme.bgPanel
    radius: isIsland ? (isReminderIsland ? 26 : 18) : Theme.radiusPanel
    z: isIsland ? 100 : 0
    property bool interactionEnabled: true
    
    // Blur spike logic
    property real animBlur: 0.0
    onIsIslandChanged: blurPulse.restart()

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: 200; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
    }

    implicitWidth: isIsland ? (isReminderIsland ? reminderIslandWidth : 600) : (layout.implicitWidth + 12)
    implicitHeight: isIsland ? (isReminderIsland ? reminderIslandHeight : 80) : (layout.implicitHeight + 14)

    transform: Translate {
        y: root.isIsland ? 28 : 0
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
    }

    // Smooth Transitions
    Behavior on color { ColorAnimation { duration: 400 } }
    Behavior on radius { NumberAnimation { duration: 400 } }
    Behavior on implicitWidth { 
        NumberAnimation { 
            duration: 1000; 
            easing.type: Easing.OutElastic
            easing.amplitude: 0.1; easing.period: 0.9 
        } 
    }
    Behavior on implicitHeight { 
        NumberAnimation { 
            duration: 600; 
            easing.type: Easing.OutElastic
            easing.amplitude: 0.9
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
                wsModel.remove(i);
                break;
            }
        }
    }

    function updateModel() {
        if (!wsList) return;
        let workspaces = wsList.filter(w => w.id > 0).sort((a, b) => a.id - b.id);
        
        for (let i = 0; i < wsModel.count; i++) {
            let currentId = wsModel.get(i).wsId;
            if (!workspaces.find(w => w.id === currentId)) {
                if (wsModel.get(i).wsIsRemoving !== true) {
                    wsModel.setProperty(i, "wsIsRemoving", true);
                }
            }
        }
        
        for (let i = 0; i < workspaces.length; i++) {
            let ws = workspaces[i];
            let foundIndex = -1;
            for (let j = 0; j < wsModel.count; j++) {
                if (wsModel.get(j).wsId === ws.id) { foundIndex = j; break; }
            }
            
            if (foundIndex === -1) {
                wsModel.insert(i, { wsId: ws.id, wsName: ws.name ? ws.name : "", wsIsRemoving: false });
            } else {
                if (wsModel.get(foundIndex).wsIsRemoving) {
                    wsModel.setProperty(foundIndex, "wsIsRemoving", false);
                }
                if (foundIndex !== i) {
                    wsModel.move(foundIndex, i, 1);
                }
                wsModel.setProperty(i, "wsName", ws.name ? ws.name : "");
            }
        }
    }

    function formatReminderTime(reminder) {
        if (!reminder || !reminder.time || reminder.time.length === 0)
            return "No time";

        return `At ${reminder.time}`;
    }

    function resolveReminderAction(action, reminderOverride) {
        let reminder = reminderOverride || IslandState.reminderData;
        if (!reminder || EventsState.reminderActionBusy)
            return;

        if (action === "snooze") {
            EventsState.snoozeReminder(reminder);
        } else if (action === "tomorrow") {
            EventsState.remindTomorrow(reminder);
        } else if (action === "complete") {
            EventsState.completeReminder(reminder);
        }

        IslandState.hide();
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
                
                property bool isActive: Hyprland.focusedWorkspace?.id === wId
                property bool isLoaded: false
                property bool isRemoving: wsIsRemoving !== undefined ? wsIsRemoving : false
                
                property bool shouldShow: isLoaded && !isRemoving
                
                Component.onCompleted: {
                    isLoaded = true
                }
                
                property real targetWidth: shouldShow ? (isActive ? 40 + 8 : 28 + 8) : 0
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
        spacing: 12
        
        opacity: root.isIsland ? 1.0 : 0.0
        scale: root.isIsland ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

        ColumnLayout {
            visible: root.isReminderIsland
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
                        text: "Mark as completed"
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
        }

        RowLayout {
            visible: !root.isReminderIsland
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
