//@ pragma UseQApplication
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
import "modules/todo"
import "modules/systemtray"
import "modules/volume"
import "components"
import "modules/vicinae"
import "modules/aside"

PanelWindow {
    GlobalShortcut {
        name: "toggle-vicinae"
        description: "Toggle Vicinae launcher"
        onPressed: vicinaeLauncher.toggleLauncher()
    }

    GlobalShortcut {
        name: "toggle-vicinae-clipboard"
        description: "Toggle Vicinae clipboard history"
        onPressed: vicinaeLauncher.toggleClipboardHistory()
    }

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
    WlrLayershell.keyboardFocus: FocusState.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: !Hyprland.focusedWindow || !Hyprland.focusedWindow.fullscreen
    
    // Маска кликабельности: собираем только те области, которые реально заняты интерфейсом
    mask: Region {
        Region { item: layoutContainer }
        Region { item: wsModule }
        Region { item: clockModule.popoutMaskItem }
        Region { item: todoModule.popoutMaskItem }
        Region { item: sysTray }
        Region { item: mathModule.popoutItem }
        Region { item: ccModule }
        Region { item: ccModule.popoutItem.maskItem }
        Region { item: audioVis.popoutMaskItem }
        Region { item: notifCardsWrapper }
    }
    
    Item {
        id: layoutContainer
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 65
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        // ─── Левая группа: Часы и Задачи ───────────────────────────────────────────
        Row {
            id: leftGroup
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            ClockModule {
                id: clockModule
                anchors.verticalCenter: parent.verticalCenter
                popoutParent: popupLayer
            }

            TodoModule {
                id: todoModule
                anchors.verticalCenter: parent.verticalCenter
                popoutParent: popupLayer
            }

            SystemTrayModule {
                id: sysTray
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ─── Центральная группа: ИДЕАЛЬНЫЙ ЦЕНТР ───────────────────────────
        Row {
            id: centerGroup
            anchors.centerIn: parent
            spacing: 20

            AnimatedBarItem {
                anchors.verticalCenter: parent.verticalCenter
                triggerState: IslandState.isActive
                slideOffsetX: 100
                opacityDuration: AnimationConfig.durationModerate

                ActiveTitleModule {}
            }

            WorkspacesModule {
                id: wsModule
                interactionEnabled: !mathModule.isActive
            }

            AnimatedBarItem {
                anchors.verticalCenter: parent.verticalCenter
                triggerState: IslandState.isActive
                slideOffsetX: -100

                MathModule {
                    id: mathModule
                }
            }
            
            AnimatedBarItem {
                anchors.verticalCenter: parent.verticalCenter
                triggerState: IslandState.isActive
                slideOffsetX: -150

                CavaVisualizer {
                    id: audioVis
                    popoutParent: popupLayer
                }
            }
        }

        // ─── Правая группа: У КРАЯ ─────────────────────────────────────────
        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            AnimatedBarItem {
                anchors.verticalCenter: parent.verticalCenter
                triggerState: ccModule.isNotifIsland
                slideOffsetX: 60
                hiddenScale: 0.5
                enableBlur: false
                slideDuration: AnimationConfig.durationSlow
                opacityDuration: AnimationConfig.durationNormal
                scaleDuration: AnimationConfig.durationModerate
                scaleEasingType: AnimationConfig.easingSpringOut

                VolumeModule {
                    id: volModule
                }
            }

            AsideModule {
                id: asideModule
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

    Item {
        id: popupLayer
        anchors.fill: parent
        z: 900
    }

    // ─── Notification cards below the island ────────────────────────────
    Item {
        id: notifCardsWrapper
        anchors.right: parent.right
        anchors.rightMargin: 20
        visible: !ccModule.popoutOpen && ccModule.isNotifIsland
        y: {
            if (!ccModule.isNotifIsland) return layoutContainer.height + 8
            var islandBottom = layoutContainer.y + rightGroup.y + ccModule.parent.y + ccModule.y + ccModule.implicitHeight
            return islandBottom + 8
        }
        Behavior on y { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

        readonly property int bottomFadeHeight: 260
        readonly property real availableHeight: Math.max(0, 800 - y - 20)
        readonly property bool contentOverflows: notifCards.implicitHeight > availableHeight
        width: notifCards.implicitWidth
        height: contentOverflows ? availableHeight : notifCards.implicitHeight
        clip: true

        NotifCardStack {
            id: notifCards
            width: notifCardsWrapper.width
            height: implicitHeight
            islandNotification: ccModule.currentNotification
            viewportHeight: notifCardsWrapper.height
            bottomFadeHeight: notifCardsWrapper.bottomFadeHeight
            promotionOverlayParent: notifCardsWrapper.parent
            promotionOverlayX: notifCardsWrapper.x
            promotionOverlayY: notifCardsWrapper.y
            promotionOverlayZ: layoutContainer.z - 1
        }
    }

    VicinaePopup {
        id: vicinaeLauncher
        visible: false
        launchOriginX: layoutContainer.x + centerGroup.x + wsModule.x + wsModule.launcherAnchorX
        launchOriginY: layoutContainer.y + centerGroup.y + wsModule.y + wsModule.launcherAnchorY
    }

    NotificationOverlay {}
}
