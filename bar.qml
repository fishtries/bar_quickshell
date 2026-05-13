//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

import "core"
import "components/bar"
import "components"

PanelWindow {
    GlobalShortcut {
        name: "toggle-vicinae"
        description: "Toggle Vicinae launcher"
        onPressed: overlays.vicinaeLauncher.toggleLauncher()
    }

    GlobalShortcut {
        name: "toggle-vicinae-clipboard"
        description: "Toggle Vicinae clipboard history"
        onPressed: overlays.vicinaeLauncher.toggleClipboardHistory()
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
        Region { item: barContent }
        Region { item: barContent.centerSection.wsModule }
        Region { item: barContent.leftSection.clockModule.popoutMaskItem }
        Region { item: barContent.leftSection.todoModule.popoutMaskItem }
        Region { item: barContent.leftSection.sysTray }
        Region { item: barContent.centerSection.mathModule.popoutItem }
        Region { item: barContent.rightSection.ccModule }
        Region { item: barContent.rightSection.ccModule.popoutItem.maskItem }
        Region { item: barContent.centerSection.audioVis.popoutMaskItem }
        Region { item: notifCardsWrapper }
    }

    // ─── Notification cards below the island (behind bar) ──────────────
    Item {
        id: notifCardsWrapper
        anchors.right: parent.right
        anchors.rightMargin: 20
        z: 5
        visible: !barContent.rightSection.ccModule.popoutOpen && barContent.rightSection.ccModule.isNotifIsland

        readonly property int topPadding: 80

        y: {
            var baseY = barContent.height + 8
            if (barContent.rightSection.ccModule.isNotifIsland) {
                var islandBottom = barContent.y + barContent.rightSection.y + barContent.rightSection.ccModule.parent.y + barContent.rightSection.ccModule.y + barContent.rightSection.ccModule.implicitHeight
                baseY = islandBottom + 8
            }
            return baseY - topPadding
        }
        Behavior on y { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut } }

        readonly property int bottomFadeHeight: 260
        readonly property real availableHeight: Math.max(0, 800 - (y + topPadding) - 20)
        readonly property bool contentOverflows: notifCards.implicitHeight > availableHeight
        width: notifCards.implicitWidth
        height: (contentOverflows ? availableHeight : notifCards.implicitHeight) + topPadding
        clip: true

        NotifCardStack {
            id: notifCards
            y: notifCardsWrapper.topPadding
            width: notifCardsWrapper.width
            height: implicitHeight
            islandNotification: barContent.rightSection.ccModule.currentNotification
            viewportHeight: notifCardsWrapper.height - notifCardsWrapper.topPadding
            bottomFadeHeight: notifCardsWrapper.bottomFadeHeight
            promotionOverlayParent: notifCardsWrapper.parent
            promotionOverlayX: notifCardsWrapper.x
            promotionOverlayY: notifCardsWrapper.y + notifCards.y
            promotionOverlayZ: barContent.z - 1
        }
    }

    BarBackground {
        id: barContent
        popoutParent: overlays.popupLayer
    }

    GlobalOverlays {
        id: overlays
        barContainer: barContent
        centerSectionRef: barContent.centerSection
        rightSectionRef: barContent.rightSection
    }
}
