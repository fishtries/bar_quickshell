import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Effects

Item {
    id: root
    
    // Занимаемое место в RowLayout = только размер иконки
    implicitWidth: iconRect.width
    implicitHeight: iconRect.height
    
    property string pendingStatus: "off"
    property string status: "off"
    property bool popoutOpen: false
    property Item popoutItem: popout
    
    SequentialAnimation {
        id: crossfadeAnim
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { script: root.status = root.pendingStatus }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }
    
    // Process для выполнения команд оболочки и считывания результата
    Process {
        id: btPoller
        command: ["sh", "-c", "if rfkill list bluetooth | grep -q 'Soft blocked: yes'; then echo 'off'; elif [ -n \"$(bluetoothctl devices Connected)\" ]; then echo 'connected'; else echo 'on'; fi"]
        
        stdout: SplitParser {
            onRead: data => {
                let res = data.trim()
                if (res === "off" || res === "on" || res === "connected") {
                    if (res !== root.status && res !== root.pendingStatus) {
                        root.pendingStatus = res;
                        crossfadeAnim.restart();
                    }
                }
            }
        }
    }

    // Таймер, который обновляет статус каждые 2 секунды
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: btPoller.running = true
        Component.onCompleted: btPoller.running = true
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
                switch(root.status) {
                    case "connected": return "\udb80\udcaf";
                    case "on":        return "\udb80\udcaf?";
                    case "off":       return "\udb80\udcb2";
                    case "disabled":  return "\udb80\udcb2";
                    default:          return "\udb80\udcb2"; 
                }
            }
            
            color: (root.status === "on" || root.status === "connected") ? "#000000" : "#555555"
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
        btStatus: root.status
        
        onCloseRequested: root.popoutOpen = false
        
        // Привязываем к нижнему краю иконки, центрируя по горизонтали
        anchors.top: iconRect.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: iconRect.horizontalCenter
    }
}
