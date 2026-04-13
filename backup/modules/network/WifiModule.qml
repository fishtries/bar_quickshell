import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: root

    property string essid: ""
    property int signalStrength: 0
    property bool isConnected: false
    property bool popoutOpen: false
    property Item popoutItem: popout

    // Приватные свойства для анимации перехода
    property string pendingEssid: ""
    property bool pendingConnected: false

    implicitWidth: iconRect.width
    implicitHeight: iconRect.height

    SequentialAnimation {
        id: crossfadeAnim
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { 
            script: {
                root.essid = root.pendingEssid;
                root.isConnected = root.pendingConnected;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }

    Process {
        id: wifiPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -n 1"]
        
        property bool found: false

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.length > 0) {
                    let parts = line.split(":")
                    if (parts.length >= 3) {
                        wifiPoller.found = true
                        let newSsid = parts[1]
                        let newSignal = parseInt(parts[2]) || 0
                        
                        if (!root.isConnected || newSsid !== root.essid) {
                            root.pendingConnected = true;
                            root.pendingEssid = newSsid;
                            root.signalStrength = newSignal;
                            crossfadeAnim.restart();
                        } else {
                            root.signalStrength = newSignal;
                        }
                    }
                }
            }
        }
        
        onExited: {
            if (!found) {
                if (root.isConnected) {
                    root.pendingConnected = false;
                    root.pendingEssid = "";
                    root.signalStrength = 0;
                    crossfadeAnim.restart();
                }
            }
            wifiPoller.found = false;
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: wifiPoller.running = true
    }

    Component.onCompleted: wifiPoller.running = true

    Rectangle {
        id: iconRect
        width: 44
        height: 36
        radius: 18
        color: "transparent"

        Text {
            id: wifiIcon
            anchors.centerIn: parent
            
            property real blurValue: 0.0
            
            text: root.isConnected ? "\udb82\udd28" : "\udb82\udd2b"
            color: root.isConnected ? "#000000" : "#555555"
            font { pixelSize: 18; bold: true }
            
            Behavior on color { ColorAnimation { duration: 300 } }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 16
                blur: wifiIcon.blurValue
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                root.popoutOpen = !root.popoutOpen;
            }
            
            onPressed: iconRect.opacity = 0.7
            onReleased: iconRect.opacity = 1.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
    
    WifiPopout {
        id: popout
        isOpen: root.popoutOpen
        isConnected: root.isConnected
        essid: root.essid
        signalStrength: root.signalStrength
        
        onCloseRequested: root.popoutOpen = false
        
        anchors.top: iconRect.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: iconRect.horizontalCenter
    }
}

