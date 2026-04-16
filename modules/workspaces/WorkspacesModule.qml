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
    
    color: isIsland ? "#000000" : Theme.bgPanel
    radius: isIsland ? 18 : Theme.radiusPanel
    property bool interactionEnabled: true
    
    // Blur spike logic
    property real animBlur: 0.0
    onIsIslandChanged: blurPulse.restart()

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "animBlur"; from: 0; to: 1.0; duration: 200; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "animBlur"; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
    }

    implicitWidth: isIsland ? 600 : (layout.implicitWidth + 12)
    implicitHeight: isIsland ? 80 : (layout.implicitHeight + 14)

    transform: Translate {
        y: root.isIsland ? 18 : 0
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

    Component.onCompleted: updateModel()

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
