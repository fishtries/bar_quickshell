import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "core"
import "components"
import "modules/clock"
import "modules/workspaces"
import "modules/audio"
import "modules/math"
import "modules/controlcenter"
import "modules/volume"

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
        Region { item: ccModule.popoutItem }
        Region { item: audioVis.popoutItem }
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

        // ─── Центральная группа: АНТИГРАВИТАЦИОННЫЙ ОСТРОВ ────────────────
        Item {
            id: centerGroupWrapper
            anchors.centerIn: parent
            width: centerGroup.width
            height: centerGroup.height

            Row {
                id: centerGroup
                anchors.centerIn: parent
                spacing: 20
                
                // Эффект проваливания при активации напоминания
                scale: EventsState.isReminderActive ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                // Размытие виджетов
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 30
                    blur: EventsState.isReminderActive ? 0.6 : 0.0
                    Behavior on blur { NumberAnimation { duration: 600 } }
                }

                ActiveTitleModule {
                    anchors.verticalCenter: parent.verticalCenter
                }

                WorkspacesModule {
                    interactionEnabled: !EventsState.isReminderActive && !mathModule.isActive
                }

                MathModule { id: mathModule }
                
                Item {
                    width: audioVis.implicitWidth
                    height: audioVis.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    CavaVisualizer { id: audioVis }
                }
            }

            // --- Dynamic Island (Antigravity) ---
            Rectangle {
                id: antigravityIsland
                z: 100
                anchors.centerIn: parent
                color: Theme.bgPopout
                radius: height / 2
                
                property bool active: EventsState.isReminderActive
                
                // Анимированные размеры
                width: active ? Math.max(reminderText.implicitWidth + 60, 240) : 40
                height: active ? 45 : 12
                opacity: active ? 1.0 : 0.0
                
                // Резиновая анимация (Elastic)
                Behavior on width { NumberAnimation { easing.type: Easing.OutElastic; easing.amplitude: 0.6; easing.period: 0.5; duration: 900 } }
                Behavior on height { NumberAnimation { easing.type: Easing.OutElastic; easing.amplitude: 0.6; easing.period: 0.5; duration: 900 } }
                Behavior on opacity { NumberAnimation { duration: 400 } }

                AppText {
                    id: reminderText
                    anchors.centerIn: parent
                    text: EventsState.currentReminderText
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    
                    // Текст появляется только когда остров раскрылся
                    opacity: antigravityIsland.width > 200 ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
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
}
