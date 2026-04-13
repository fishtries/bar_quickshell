import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../components"
import "../../core"

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

        AppText {
            text: "Session Details"
            color: Theme.textPrimary
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
            AppText { text: "Symbols Added:"; color: Theme.textSecondary; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            AppText { text: root.addedSymbols; color: Theme.textPrimary; font.pixelSize: 13; font.bold: true }
        }

        RowLayout {
            spacing: 8
            AppText { text: "Symbols Left:"; color: Theme.textSecondary; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            AppText { text: Math.max(0, root.targetSymbols - root.addedSymbols); color: Theme.textPrimary; font.pixelSize: 13; font.bold: true }
        }

        RowLayout {
            spacing: 8
            AppText { text: "Session Complete:"; color: Theme.textSecondary; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            AppText { text: root.isReady ? "Yes" : "No"; color: root.isReady ? Theme.success : Theme.error; font.pixelSize: 13; font.bold: true }
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
                AppIcon { text: root.isReady ? "󰄬" : "󱗝"; font.pixelSize: 14; color: root.isReady ? Theme.success : Theme.textSecondary }
                AppText { 
                    text: root.isReady ? "End Session" : "Session Incomplete"
                    color: endMouse.containsMouse ? (root.isReady ? Theme.textPrimary : Theme.error) : Theme.textSecondary
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
