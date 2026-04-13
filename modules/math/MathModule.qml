import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Effects
import "../../core"
import "../../components"

Item {
    id: root

    property bool isActive: MathState.isActive
    property real progress: MathState.progress
    property bool isReady: MathState.isReady
    property int addedSymbols: MathState.addedSymbols
    property int targetSymbols: MathState.targetSymbols

    property bool popoutOpen: MathState.popoutOpen
    property Item popoutItem: popout

    implicitWidth: barContainer.width
    implicitHeight: 36

    function refresh() {
        MathState.refresh()
    }

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
                
                AppText {
                    anchors.centerIn: parent
                    text: Math.round(root.progress * 100) + "%"
                    color: root.isReady ? Theme.textDark : Theme.textPrimary
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
            onClicked: MathState.popoutOpen = !MathState.popoutOpen
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
        
        onCloseRequested: MathState.popoutOpen = false
        onEndSession: {
            MathState.endSession();
        }
        
        anchors.top: barContainer.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: barContainer.horizontalCenter
        
        anchors.horizontalCenterOffset: root.isActive ? 0 : -30
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

        originX: (popout.popoutWidth / 2) - anchors.horizontalCenterOffset
    }
}
