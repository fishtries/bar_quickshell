import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "core"
import "modules/clock"
import "modules/workspaces"
import "modules/audio"
import "modules/math"
import "modules/controlcenter"
import "modules/notifications"
import "modules/volume"
import "components"

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true
    // Резервируем ровно 65 пикселей для всех других окон
    WlrLayershell.exclusiveZone: 50

    // Окно всегда имеет запас высоты для попаута (оно прозрачное, так что лишнее место невидимо)
    // exclusiveZone гарантирует, что другие окна резервируют только 65px
    // Увеличено до 800, чтобы не обрезалось высокое меню Wi-Fi
    implicitHeight: 800
    
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: clockModule.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: !Hyprland.focusedWindow || !Hyprland.focusedWindow.fullscreen
    
    // Маска кликабельности: собираем только те области, которые реально заняты интерфейсом
    mask: Region {
        Region { item: layoutContainer }
        Region { item: clockModule.popoutItem }
        Region { item: mathModule.popoutItem }
        Region { item: ccModule.popoutItem.maskItem }
        Region { item: audioVis.popoutItem }
        Region { item: notifCards }
    }
    
    Item {
        id: layoutContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 65
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        // ─── Левая группа: Часы ───────────────────────────────────────────
        ClockModule {
            id: clockModule
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        // ─── Центральная группа: ИДЕАЛЬНЫЙ ЦЕНТР ───────────────────────────
        Row {
            id: centerGroup
            anchors.centerIn: parent
            spacing: 20

            ActiveTitleModule {
                anchors.verticalCenter: parent.verticalCenter
                opacity: IslandState.isActive ? 0 : 1
                scale: IslandState.isActive ? 0.1 : 1.0
                transform: Translate {
                    x: IslandState.isActive ? 100 : 0
                    Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.Elastic; easing.period: 0.5 } }

                layer.enabled: IslandState.isActive
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: IslandState.isActive ? 1.0 : 0.0
                    Behavior on blur { NumberAnimation { duration: 400 } }
                }
            }

            WorkspacesModule {
                interactionEnabled: !mathModule.isActive
            }

            MathModule { 
                id: mathModule 
                opacity: IslandState.isActive ? 0 : 1
                scale: IslandState.isActive ? 0.1 : 1.0
                transform: Translate {
                    x: IslandState.isActive ? -100 : 0
                    Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.Elastic; easing.period: 0.5 } }

                layer.enabled: IslandState.isActive
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: IslandState.isActive ? 1.0 : 0.0
                    Behavior on blur { NumberAnimation { duration: 400 } }
                }
            }
            
            Item {
                width: audioVis.implicitWidth
                height: audioVis.implicitHeight
                anchors.verticalCenter: parent.verticalCenter
                opacity: IslandState.isActive ? 0 : 1
                scale: IslandState.isActive ? 0.1 : 1.0
                transform: Translate {
                    x: IslandState.isActive ? -150 : 0
                    Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.Elastic; easing.period: 0.5 } }
                
                layer.enabled: IslandState.isActive
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: IslandState.isActive ? 1.0 : 0.0
                    Behavior on blur { NumberAnimation { duration: 400 } }
                }

                CavaVisualizer { id: audioVis }
            }
        }

        // ─── Правая группа: У КРАЯ ─────────────────────────────────────────
        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            VolumeModule { 
                id: volModule 
                anchors.verticalCenter: parent.verticalCenter
                opacity: ccModule.isNotifIsland ? 0 : 1
                scale: ccModule.isNotifIsland ? 0.5 : 1.0
                transform: Translate {
                    x: ccModule.isNotifIsland ? 60 : 0
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutElastic; easing.period: 0.5 } }
            }

            // Control Center
            Item {
                width: ccModule.implicitWidth
                height: ccModule.implicitHeight
                ControlCenterModule {
                    id: ccModule
                }
            }
        }
    }

    // ─── Notification cards below the island ────────────────────────────
    NotifCardStack {
        id: notifCards
        anchors.right: parent.right
        anchors.rightMargin: 20
        visible: !ccModule.popoutOpen && ccModule.isNotifIsland
        y: {
            if (!ccModule.isNotifIsland) return layoutContainer.height + 8
            // Island visual bottom = layoutContainer center + island height/2 + translate offset
            var islandH = ccModule.notifExpanded ? 120 : 64
            var translateY = ccModule.notifExpanded ? 48 : 18
            var islandBottom = 32 + islandH / 2 + translateY
            return islandBottom + 8
        }
        Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        islandNotification: ccModule.currentNotification
    }

    NotificationOverlay {}
}
