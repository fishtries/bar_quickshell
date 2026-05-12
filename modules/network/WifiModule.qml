import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import QtQuick.Effects
import "../../core"

Item {
    id: root

    property bool popoutOpen: false
    property Item popoutItem: popout

    implicitWidth: iconRect.width
    implicitHeight: iconRect.height

    SequentialAnimation {
        id: crossfadeAnim
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { 
            script: NetworkState.commitWifiUpdate()
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }

    Connections {
        target: NetworkState
        function onWifiUpdateTriggered() {
            crossfadeAnim.restart();
        }
    }

    Binding {
        target: NetworkState
        property: "popoutOpen"
        value: root.popoutOpen
    }

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
            
            text: NetworkState.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
            color: NetworkState.wifiConnected ? "#000000" : "#555555"
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
        
        onCloseRequested: root.popoutOpen = false
        
        anchors.top: iconRect.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: iconRect.horizontalCenter
    }
}

