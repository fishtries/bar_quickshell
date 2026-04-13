import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Effects

import "../../components"

PopoutWrapper {
    id: root

    property string btStatus: "off"
    
    // MAC-адрес устройства, к которому идёт подключение/отключение
    property string pendingMac: ""

    // Заголовок
    Text {
        text: "Bluetooth"
                    color: "#ffffff"
                    font { pixelSize: 16; bold: true }
                }
                
                // Разделитель
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                
                // Статус
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    
                    Text {
                        text: {
                            switch(root.btStatus) {
                                case "connected": return "\udb80\udcaf";
                                case "on":        return "\udb80\udcaf"; 
                                default:          return "\udb80\udcb2";
                            }
                        }
                        color: (root.btStatus === "on" || root.btStatus === "connected") ? "#ffffff" : "#717171"
                        font { pixelSize: 20; bold: true }
                    }
                    
                    Text {
                        text: {
                            switch(root.btStatus) {
                                case "connected": return "Connected";
                                case "on":        return "No connection";
                                case "off":       return "Bluetooth Off";
                                default:          return "Searching...";
                            }
                        }
                        color: "#e0e0e0"
                        font.pixelSize: 14
                    }
                }
                
                // Список подключённых устройств
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: connectedDevicesColumn.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: connectedModel.count > 0
                    
                    ColumnLayout {
                        id: connectedDevicesColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        
                        Text {
                            text: "Connected Device"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }
                        
                        Repeater {
                            model: connectedModel
                            
                            Rectangle {
                                id: connectedDeviceRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: mouseAreaC.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true
                                
                                required property var modelData
                                property bool isPending: root.pendingMac === modelData.mac
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                // Шиммер-блик
                                Rectangle {
                                    opacity: connectedDeviceRect.isPending ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 600 } }
                                    width: parent.width * 0.4
                                    height: parent.height
                                    radius: parent.radius
                                    y: 0
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: parent.opacity > 0
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -connectedDeviceRect.width * 0.4; to: connectedDeviceRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8
                                    
                                    Text {
                                        text: "\udb80\udcaf"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: modelData.name || ""
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseAreaC
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingMac = modelData.mac;
                                        Hyprland.dispatch("exec bluetoothctl disconnect " + modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Сопряжённые устройства
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: pairedDevicesColumn.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: pairedModel.count > 0
                    
                    ColumnLayout {
                        id: pairedDevicesColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        
                        Text {
                            text: "Paired Devices"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }
                        
                        Repeater {
                            model: pairedModel
                            
                            Rectangle {
                                id: pairedDeviceRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: mouseAreaP.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true
                                
                                required property var modelData
                                property bool isPending: root.pendingMac === modelData.mac
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                // Шиммер-блик
                                Rectangle {
                                    opacity: pairedDeviceRect.isPending ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 600 } }
                                    width: parent.width * 0.4
                                    height: parent.height
                                    radius: parent.radius
                                    y: 0
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: parent.opacity > 0
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -pairedDeviceRect.width * 0.4; to: pairedDeviceRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8
                                    
                                    Text {
                                        text: "\udb80\udcaf"
                                        color: pairedDeviceRect.isPending ? "#ffffff" : "#888888"
                                        font.pixelSize: 14
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text {
                                        text: modelData.name || ""
                                        color: pairedDeviceRect.isPending ? "#ffffff" : "#a0a0a0"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseAreaP
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingMac = modelData.mac;
                                        Hyprland.dispatch("exec bluetoothctl connect " + modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Разделитель
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                
                // Кнопка "Настройки"
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: settingsArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Open Bluetooth Manager"
                        color: "#ffffff"
                        font { pixelSize: 13 }
                    }
                    
                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Hyprland.dispatch("exec blueman-manager")
                            root.closeRequested();
                        }
                    }
                }

    
    // Процесс для получения списка устройств
    ListModel { id: connectedModel }
    ListModel { id: pairedModel }
    
    Process {
        id: devicePoller
        command: ["sh", "-c", "echo '==CONNECTED=='; bluetoothctl devices Connected; echo '==PAIRED=='; bluetoothctl devices Paired"]
        
        stdout: SplitParser {
            property string currentMode: "none"
            property var tempConnected: []
            property var tempPaired: []
            
            onRead: data => {
                let line = data.trim();
                if (line === "==CONNECTED==") { 
                    currentMode = "connected"; 
                    tempConnected = []; 
                    return; 
                }
                if (line === "==PAIRED==") { 
                    currentMode = "paired"; 
                    tempPaired = []; 
                    return; 
                }
                
                if (line.length > 0 && line.startsWith("Device")) {
                    let parts = line.split(" ");
                    if (parts.length >= 3) {
                        let mac = parts[1];
                        let name = parts.slice(2).join(" ");
                        
                        if (currentMode === "connected") {
                            tempConnected.push({ mac: mac, name: name });
                        } else if (currentMode === "paired") {
                            let isConnected = tempConnected.some(d => d.mac === mac);
                            if (!isConnected) {
                                  tempPaired.push({ mac: mac, name: name });
                            }
                        }
                    }
                }
            }
        }
        
        onExited: {
            const parser = stdout as SplitParser;
            
            // Атомарно обновляем модели, чтобы избежать "прыжков" высоты
            connectedModel.clear();
            for (let item of parser.tempConnected) connectedModel.append(item);
            
            pairedModel.clear();
            for (let item of parser.tempPaired) pairedModel.append(item);
            
            // Если устройство перешло из одного списка в другой — сбросить shimmer
            if (root.pendingMac !== "") {
                let stillExists = false;
                for (let i = 0; i < pairedModel.count; i++) {
                    if (pairedModel.get(i).mac === root.pendingMac) { stillExists = true; break; }
                }
                if (!stillExists) {
                    for (let i = 0; i < connectedModel.count; i++) {
                        if (connectedModel.get(i).mac === root.pendingMac) { stillExists = true; break; }
                    }
                }
                // Устройство поменяло категорию — операция завершена
                root.pendingMac = "";
            }
        }
    }
    
    Timer {
        interval: 3000
        running: root.isOpen
        repeat: true
        onTriggered: {
            devicePoller.running = true;
        }
    }
    
    onIsOpenChanged: {
        if (isOpen) {
            devicePoller.running = true;
        }
    }
}