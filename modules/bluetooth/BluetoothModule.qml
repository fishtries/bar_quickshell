import QtQuick
import Quickshell
import QtQuick.Effects
import "../../core"

Item {
    id: root
    
    // Занимаемое место в RowLayout = только размер иконки
    implicitWidth: iconRect.width
    implicitHeight: iconRect.height
    
    property bool popoutOpen: false
    property Item popoutItem: popout
    
    SequentialAnimation {
        id: crossfadeAnim
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { script: BluetoothState.commitBtUpdate() }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }

    Connections {
        target: BluetoothState
        function onBtUpdateTriggered() {
            crossfadeAnim.restart();
        }
    }

    Binding {
        target: BluetoothState
        property: "popoutOpen"
        value: root.popoutOpen
    }
    
    // Сама иконка-островок (фон убран, иконка стала прозрачной)
    Rectangle {
        id: iconRect
        width: 44
        height: 36
        radius: 18
        color: "transparent"
    
        Text {
            id: btIcon
            anchors.centerIn: parent
            
            property real blurValue: 0.0
            
            text: {
                switch(BluetoothState.btStatus) {
                    case "connected": return "\udb80\udcaf";
                    case "on":        return "\udb80\udcaf?";
                    case "off":       return "\udb80\udcb2";
                    case "disabled":  return "\udb80\udcb2";
                    default:          return "\udb80\udcb2"; 
                }
            }
            
            color: (BluetoothState.btStatus === "on" || BluetoothState.btStatus === "connected") ? "#000000" : "#555555"
            font { pixelSize: 18; bold: true }
            
            Behavior on color { ColorAnimation { duration: 300 } }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 16
                blur: btIcon.blurValue
            }
        }
        
        MouseArea {
            anchors.fill: parent
            
            onClicked: {
                root.popoutOpen = !root.popoutOpen;
            }
            
            onPressed: iconRect.opacity = 0.7
            onReleased: iconRect.opacity = 1.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
    
    // Попаут: расположен ПОД иконкой, с небольшим отступом
    BluetoothPopout {
        id: popout
        isOpen: root.popoutOpen
        
        onCloseRequested: root.popoutOpen = false
        
        // Привязываем к нижнему краю иконки, центрируя по горизонтали
        anchors.top: iconRect.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: iconRect.horizontalCenter
    }
}
