import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../components"

PopoutWrapper {
    id: root
    
    property bool isConnected: false
    property string essid: ""
    property int signalStrength: 0
    
    // MAC-адрес/название устройства, к которому идёт подключение/отключение
    property string pendingId: ""
    property bool showAvailableWF: false
    
    Text {
        text: "Network"
        color: "#ffffff"
        font { pixelSize: 16; bold: true }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    
                    Text {
                        text: root.isConnected ? "\udb82\udd28" : "\udb82\udd2b"
                        color: root.isConnected ? "#ffffff" : "#717171"
                        font { pixelSize: 20; bold: true }
                    }
                    
                    Text {
                        text: root.isConnected ? `Connected to ${root.essid}` : "Disconnected"
                        color: "#e0e0e0"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Кнопка отключения
                    Rectangle {
                        visible: root.isConnected
                        implicitWidth: 70
                        implicitHeight: 26
                        radius: 13
                        color: disconnectMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: disconnectMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.3) : "transparent"
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            color: disconnectMouse.containsMouse ? "#ff5555" : "#aaaaaa"
                            font.pixelSize: 11
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: disconnectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pendingId = root.essid;
                                Hyprland.dispatch(`exec nmcli connection down id "${root.essid}"`)
                            }
                        }
                    }
                }
                
                // Подключённая сеть
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: connectedCol.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: currentConnModel.count > 0
                    
                    ColumnLayout {
                        id: connectedCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        
                        Text {
                            text: "Connected Network"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }
                        
                        Repeater {
                            model: currentConnModel
                            
                            Rectangle {
                                id: currWifiRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: mouseAreaW1.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true
                                
                                required property var modelData
                                property bool isPending: root.pendingId === modelData.ssid
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                Rectangle {
                                    opacity: currWifiRect.isPending ? 1.0 : 0.0
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
                                        NumberAnimation { from: -currWifiRect.width * 0.4; to: currWifiRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8
                                    
                                    Text {
                                        text: "\udb82\udd28"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: modelData.ssid || ""
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseAreaW1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingId = modelData.ssid;
                                        Hyprland.dispatch(`exec nmcli connection down id "${modelData.ssid}"`)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Доступные сети
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: availWfCol.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: availWfModel.count > 0
                    
                    ColumnLayout {
                        id: availWfCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: headerRow.implicitHeight
                            
                            RowLayout {
                                id: headerRow
                                anchors.fill: parent
                                spacing: 4
                                
                                Text {
                                    text: "Available Networks"
                                    color: "#888888"
                                    font { pixelSize: 11; bold: true }
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: root.showAvailableWF ? "▲" : "▼"
                                    color: "#888888"
                                    font { pixelSize: 10 }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAvailableWF = !root.showAvailableWF
                            }
                        }
                        
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: root.showAvailableWF ? availWfInternalCol.implicitHeight : 0
                            clip: true
                            opacity: root.showAvailableWF ? 1 : 0
                            Behavior on implicitHeight { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
                            
                            ColumnLayout {
                                id: availWfInternalCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 6
                                
                                Repeater {
                                    model: availWfModel
                                    
                                    Rectangle {
                                        id: availWifiRect
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 6
                                        color: mouseAreaW2.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                        clip: true
                                        
                                        required property var modelData
                                        property bool isPending: root.pendingId === modelData.ssid
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        
                                        Rectangle {
                                            opacity: availWifiRect.isPending ? 1.0 : 0.0
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
                                                NumberAnimation { from: -availWifiRect.width * 0.4; to: availWifiRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                                PauseAnimation { duration: 300 }
                                            }
                                        }
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 8
                                            
                                            Text {
                                                text: "\udb82\udd28"
                                                color: availWifiRect.isPending ? "#ffffff" : "#888888"
                                                font.pixelSize: 14
                                                Behavior on color { ColorAnimation { duration: 300 } }
                                            }
                                            Text {
                                                text: modelData.ssid || ""
                                                color: availWifiRect.isPending ? "#ffffff" : "#a0a0a0"
                                                font.pixelSize: 13
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                Behavior on color { ColorAnimation { duration: 300 } }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: mouseAreaW2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.pendingId = modelData.ssid;
                                                Hyprland.dispatch(`exec nmcli device wifi connect "${modelData.ssid}"`)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                

                

    
    ListModel { id: currentConnModel }
    ListModel { id: availWfModel }
    
    Process {
        id: networkPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi"]
        
        stdout: SplitParser {
            property var tempCurrWifi: []
            property var tempAvailWifi: []
            property var seenSsid: []
            
            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;
                
                let firstColon = line.indexOf(':');
                if (firstColon !== -1) {
                    let activeStr = line.substring(0, firstColon);
                    let rest = line.substring(firstColon + 1);
                    let lastColon = rest.lastIndexOf(':');
                    if (lastColon !== -1) {
                        let ssid = rest.substring(0, lastColon);
                        let signal = rest.substring(lastColon + 1);
                        
                        // Пропускаем пустые SSID и дубликаты
                        if (ssid.length > 0 && ssid !== "--" && !seenSsid.includes(ssid)) {
                            seenSsid.push(ssid);
                            if (activeStr === "yes") {
                                tempCurrWifi.push({ ssid: ssid, signal: signal });
                            } else {
                                // Ограничиваем список 8 сетями
                                if (tempAvailWifi.length < 8) {
                                    tempAvailWifi.push({ ssid: ssid, signal: signal });
                                }
                            }
                        }
                    }
                }
            }
        }
        
        onExited: {
            const parser = stdout as SplitParser;
            
            currentConnModel.clear();
            for (let item of parser.tempCurrWifi) currentConnModel.append(item);
            
            availWfModel.clear();
            for (let item of parser.tempAvailWifi) availWfModel.append(item);
            
            parser.tempCurrWifi = [];
            parser.tempAvailWifi = [];
            parser.seenSsid = [];
            
            if (root.pendingId !== "") {
                let stillPending = false;
                // Just rudimentary check to see if we can drop pending state
                root.pendingId = "";
            }
        }
    }
    
    Timer {
        interval: 3000
        running: root.isOpen
        repeat: true
        onTriggered: {
            networkPoller.running = true;
        }
    }
    
    onIsOpenChanged: {
        if (isOpen) {
            networkPoller.running = true;
        }
    }
}
