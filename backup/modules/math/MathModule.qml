import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: root

    property bool isActive: false
    property real progress: 0.0
    property bool isReady: false
    property int addedSymbols: 0
    property int targetSymbols: 500

    property bool popoutOpen: false
    property Item popoutItem: popout

    implicitWidth: barContainer.width
    implicitHeight: 36 // Фиксированная высота для выравнивания в Row

    function refresh() {
        validatorPoller.running = true;
    }

    Process {
        id: validatorPoller
        command: ["python", "/home/fish/.config/quickshell/modules/math/math_validator.py", "--check"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.error) {
                        root.isActive = false;
                        root.progress = 0.0;
                        root.isReady = false;
                        root.addedSymbols = 0;
                    } else {
                        root.isActive = true;
                        root.progress = parsed.progress !== undefined ? parsed.progress : 0.0;
                        root.isReady = parsed.is_ready === true;
                        root.addedSymbols = parsed.added_symbols !== undefined ? parsed.added_symbols : 0;
                    }
                } catch(e) { }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: validatorPoller.running = true
    }

    Component.onCompleted: validatorPoller.running = true

    Rectangle {
        id: barContainer
        // Анимируем ширину (когда не активен - полностью исчезает)
        width: root.isActive ? 150 : 0
        height: root.isActive ? 36 : 0
        radius: height / 2
        opacity: root.isActive ? 1.0 : 0.0
        visible: opacity > 0
        
        // Позиционирование по центру родителя (Item 36px высотой)
        anchors.centerIn: parent
        
        color: root.isActive ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(0, 0, 0, 0.3)

        Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutExpo} }
        Behavior on height { NumberAnimation { duration: 700; easing.type: Easing.OutExpo} }
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 300 } }

        // Эффект блюра при появлении и исчезновении
        property real blurValue: root.isActive ? 0.0 : 0.8
        
        layer.enabled: blurValue > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: barContainer.blurValue
        }

        Behavior on blurValue {
            NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
        }

        // Содержимое
        Item {
            anchors.fill: parent
            visible: root.isActive 
            clip: true

            // Индикатор прогресса
            Rectangle {
                anchors.centerIn: parent
                width: 130
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.1)
                border.color: root.isReady ? "#55ff55" : "transparent"
                border.width: root.isReady ? 1 : 0
                clip: true
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, root.progress))
                    radius: parent.radius
                    color: root.isReady ? "#55ff55" : "#ffffff"
                    
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: Math.round(root.progress * 100) + "%"
                    color: root.isReady ? "#000000" : "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                    opacity: barContainer.width > 100 ? 1.0 : 0.0 
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popoutOpen = !root.popoutOpen
        }
    }

    MathPopout {
        id: popout
        isOpen: root.popoutOpen
        isActive: root.isActive
        progress: root.progress
        isReady: root.isReady
        addedSymbols: root.addedSymbols
        targetSymbols: root.targetSymbols
        
        onCloseRequested: root.popoutOpen = false
        onEndSession: {
            root.popoutOpen = false;
            endSessionProcess.running = true;
        }
        
        anchors.top: barContainer.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: barContainer.horizontalCenter
        
        // Смещаем попап левее только когда сессия НЕ начата
        anchors.horizontalCenterOffset: root.isActive ? 0 : -30
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

        // Точка начала анимации (из центра точки на баре)
        // Если попап смещен влево, точка входа смещается вправо относительно центра попапа
        originX: (popout.popoutWidth / 2) - anchors.horizontalCenterOffset
    }
    
    Process {
        id: startSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/modules/math/math_control.sh", "start"]
        onExited: validatorPoller.running = true
    }
    
    Process {
        id: endSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/modules/math/math_control.sh", "stop"]
        onExited: {
            root.isActive = false;
            root.progress = 0.0;
            root.isReady = false;
            root.addedSymbols = 0;
            validatorPoller.running = true;
        }
    }
}
