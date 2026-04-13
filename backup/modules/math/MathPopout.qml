import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../components"

PopoutWrapper {
    id: root
    
    property bool isActive: false
    property real progress: 0.0
    property bool isReady: false
    property int addedSymbols: 0
    property int targetSymbols: 500

    signal endSession()

    // Эффект блюра при открытии попаута для деталей
    SequentialAnimation {
        id: stateBlurAnim
        NumberAnimation { target: mainContent; property: "targetBlur"; from: 0.6; to: 0.0; duration: 450; easing.type: Easing.OutCubic }
    }

    onIsOpenChanged: {
        if (root.isOpen) {
            stateBlurAnim.restart();
        }
    }

    ColumnLayout {
        id: mainContent
        Layout.fillWidth: true
        spacing: 12

        property real targetBlur: 0.0

        layer.enabled: targetBlur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: mainContent.targetBlur
        }

        Text {
            text: "Session Details"
            color: "#ffffff"
            font { pixelSize: 16; bold: true }
            Layout.alignment: Qt.AlignHCenter
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.1)
        }
        
        RowLayout {
            spacing: 8
            Text { text: "Symbols Added:"; color: "#aaaaaa"; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            Text { text: root.addedSymbols; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
        }

        RowLayout {
            spacing: 8
            Text { text: "Symbols Left:"; color: "#aaaaaa"; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            Text { text: Math.max(0, root.targetSymbols - root.addedSymbols); color: "#ffffff"; font.pixelSize: 13; font.bold: true }
        }

        RowLayout {
            spacing: 8
            Text { text: "Session Complete:"; color: "#aaaaaa"; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            Text { text: root.isReady ? "Yes" : "No"; color: root.isReady ? "#55ff55" : "#ff5555"; font.pixelSize: 13; font.bold: true }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 4 }

        // Кнопка завершения сессии
        Rectangle {
            id: endBtn
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 18
            color: endMouse.containsMouse ? (root.isReady ? Qt.rgba(0, 1, 0, 0.15) : Qt.rgba(1, 0, 0, 0.1)) : Qt.rgba(1, 1, 1, 0.08)
            border.color: endMouse.containsMouse ? (root.isReady ? Qt.rgba(0, 1, 0, 0.3) : Qt.rgba(1, 0, 0, 0.2)) : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text { text: root.isReady ? "󰄬" : "󱗝"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: root.isReady ? "#55ff55" : "#aaaaaa" }
                Text { 
                    text: root.isReady ? "End Session" : "Session Incomplete"
                    color: endMouse.containsMouse ? (root.isReady ? "#ffffff" : "#ff5555") : "#aaaaaa"
                    font.pixelSize: 13; font.bold: true 
                }
            }

            MouseArea {
                id: endMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.isReady ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: {
                    if (root.isReady) root.endSession();
                }
            }
        }
    }
}
