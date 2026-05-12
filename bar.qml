//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

import "core"
import "components/bar"

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
        Region { item: overlays.notifCardsWrapper }
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
