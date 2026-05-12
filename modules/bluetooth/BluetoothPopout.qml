import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Effects

import "../../components"
import "../../core"

PopoutWrapper {
    id: root

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
                            switch(BluetoothState.btStatus) {
                                case "connected": return "\udb80\udcaf";
                                case "on":        return "\udb80\udcaf"; 
                                default:          return "\udb80\udcb2";
                            }
                        }
                        color: (BluetoothState.btStatus === "on" || BluetoothState.btStatus === "connected") ? "#ffffff" : "#717171"
                        font { pixelSize: 20; bold: true }
                    }
                    
                    Text {
                        text: {
                            switch(BluetoothState.btStatus) {
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
                    visible: BluetoothState.connectedDevices.count > 0
                    
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
                            model: BluetoothState.connectedDevices
                            
                            Rectangle {
                                id: connectedDeviceRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: mouseAreaC.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true
                                
                                required property var modelData
                                property bool isPending: BluetoothState.pendingMac === modelData.mac
                                
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
                                    onClicked: BluetoothState.disconnectDevice(modelData.mac)
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
                    visible: BluetoothState.pairedDevices.count > 0
                    
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
                            model: BluetoothState.pairedDevices
                            
                            Rectangle {
                                id: pairedDeviceRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: mouseAreaP.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true
                                
                                required property var modelData
                                property bool isPending: BluetoothState.pendingMac === modelData.mac
                                
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
                                    onClicked: BluetoothState.connectDevice(modelData.mac)
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
                            BluetoothState.openManager();
                            root.closeRequested();
                        }
                    }
                }
}