import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../components"
import "../../core"

Rectangle {
    id: root
    color: Theme.bgPanel
    radius: Theme.radiusPanel
    property bool interactionEnabled: true

    implicitWidth: layout.implicitWidth + 12
    implicitHeight: layout.implicitHeight + 14

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

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 0

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
                        enabled: root.interactionEnabled
                        onClicked: Hyprland.dispatch("workspace " + wId)
                    }
                }
            }
        }
    }
}
