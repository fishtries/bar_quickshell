pragma Singleton
import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    property string activeTitle: {
        const top = Hyprland.activeToplevel;
        if (top) return top.title;
        
        const win = Hyprland.focusedWindow;
        if (win) return win.title;
        
        return "";
    }

    property string activeClass: {
        const top = Hyprland.activeToplevel;
        if (top && top.lastIpcObject) return top.lastIpcObject.class || "";
        return "";
    }

    // Слушаем события Hyprland для принудительного обновления списка окон
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (["openwindow", "closewindow", "movewindow", "activewindow", "fullscreen"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }
    }
}
