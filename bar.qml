import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "core"
import "core/state"
import "modules/clock"
import "modules/workspaces"
import "modules/audio"
import "modules/math"
import "modules/controlcenter"
import "modules/volume"
import QtQuick.Effects

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

        // ─── СЛОЙ 1 (z: 1): ФОНОВЫЕ МОДУЛИ ───────────────────────────────
        Item {
            id: backdrop
            anchors.fill: parent
            z: 1

            // Анимации размытия и масштаба
            scale: EventsState.isReminderActive ? 0.95 : 1.0
            
            // Слой эффектов
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: EventsState.isReminderActive ? 0.8 : 0.0
                
                Behavior on blur { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
            }

            Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

            // Левая группа: Часы
            ClockModule {
                id: clockModule
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            // Центральная группа (без воркспейсов, они в острове)
            Row {
                id: centerGroup
                anchors.centerIn: parent
                spacing: 20
                visible: !EventsState.isReminderActive
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                ActiveTitleModule {
                    anchors.verticalCenter: parent.verticalCenter
                }

                MathModule { id: mathModule }
                
                Item {
                    width: audioVis.implicitWidth
                    height: audioVis.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    CavaVisualizer { id: audioVis }
                }
            }

            // Правая группа
            Row {
                id: rightGroup
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                VolumeModule { 
                    id: volModule 
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: ccModule.implicitWidth
                    height: ccModule.implicitHeight
                    ControlCenterModule {
                        id: ccModule
                    }
                }
            }
        }

        // ─── СЛОЙ 2 (z: 100): DYNAMIC ISLAND ────────────────────────────
        Item {
            id: islandContainer
            anchors.centerIn: parent
            z: 100

            Rectangle {
                id: island
                anchors.centerIn: parent
                color: "black"
                radius: EventsState.isReminderActive ? 18 : 12

                // Размеры острова
                width: EventsState.isReminderActive 
                    ? reminderText.implicitWidth + 60 
                    : workspaces.implicitWidth + 10
                height: EventsState.isReminderActive ? 42 : 32

                Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on radius { NumberAnimation { duration: 450 } }

                // Воркспейсы (прячутся при активации напоминания)
                WorkspacesModule {
                    id: workspaces
                    anchors.centerIn: parent
                    opacity: EventsState.isReminderActive ? 0 : 1
                    visible: opacity > 0
                    interactionEnabled: !EventsState.isReminderActive
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                // Текст напоминания (появляется при активации)
                AppText {
                    id: reminderText
                    text: EventsState.currentReminderText
                    anchors.centerIn: parent
                    color: "white"
                    font { pixelSize: 15; weight: Font.Medium }
                    opacity: EventsState.isReminderActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 350 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (EventsState.isReminderActive) {
                            clockModule.popoutOpen = !clockModule.popoutOpen;
                        }
                    }
                }
            }
        }
    }
}
