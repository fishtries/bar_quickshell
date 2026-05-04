import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../../core"

Item {
    id: root
    
    property bool isActive: false
    property real currentWidth: isActive ? 80 : 0
    property real blurLevel: isActive ? 0.0 : 1.0

    property bool popoutOpen: false
    property Item popoutItem: mediaPopout
    property Item popoutMaskItem: mediaPopout.maskItem
    property Item popoutParent: null
    readonly property Item effectivePopoutParent: popoutParent ? popoutParent : root
    readonly property real effectiveWidth: root.width > 0 ? root.width : root.implicitWidth
    readonly property real effectiveHeight: root.height > 0 ? root.height : root.implicitHeight
    readonly property var popoutPosition: root.mapToItem(root.effectivePopoutParent, root.effectiveWidth / 2, root.effectiveHeight + 28)
    
    implicitWidth: currentWidth
    implicitHeight: 20
    
    opacity: isActive ? 1.0 : 0.0
    
    Behavior on currentWidth { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    Behavior on blurLevel { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    
    property var values: [0, 0, 0, 0, 0, 0]
    
    Timer {
        id: inactivityTimer
        interval: 2000
        onTriggered: root.isActive = false
    }
    
    Process {
        id: cavaProcess
        command: ["sh", "-c", "cava -p ~/.config/quickshell/modules/audio/cava.conf"]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;
                
                let parts = line.split(';');
                if (parts.length >= 6) {
                    let newVals = [];
                    let hasAudio = false;
                    for (let i = 0; i < 6; i++) {
                        let val = parseInt(parts[i]) || 0;
                        newVals.push(val);
                        if (val > 0) hasAudio = true;
                    }
                    root.values = newVals;
                    
                    if (hasAudio) {
                        root.isActive = true;
                        inactivityTimer.restart();
                    }
                }
            }
        }
    }
    
    Item {
        id: barsContainer
        anchors.fill: parent
        clip: true

        layer.enabled: root.blurLevel > 0.0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 30
            blur: root.blurLevel
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 1
            
            Repeater {
                model: 6
                
                Rectangle {
                    width: 10
                    height: Math.max(4, (root.values[index] / 100) * parent.height)
                    anchors.bottom: parent.bottom
                    color: Theme.foregroundForItem(parent)
                    radius: 2
                    
                    Behavior on height { 
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad } 
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popoutOpen = !root.popoutOpen
    }

    MediaPopout {
        id: mediaPopout
        parent: root.effectivePopoutParent
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false

        x: root.popoutPosition.x - (width / 2)
        y: root.popoutPosition.y
        z: 1000
    }
}
