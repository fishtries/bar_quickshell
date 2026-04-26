pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: root

    property bool isExpanded: false

    function toggle() {
        root.isExpanded = !root.isExpanded;
    }

    readonly property var pinnedItems: {
        const items = SystemTray.items.values;
        const result = [];

        if (!items)
            return result;

        for (let i = 0; i < items.length; i++) {
            const item = items[i];

            if (!item)
                continue;

            if (item.status === Status.Active || item.status === Status.NeedsAttention)
                result.push(item);
        }

        return result;
    }

    readonly property var backgroundItems: {
        const items = SystemTray.items.values;
        const result = [];

        if (!items)
            return result;

        for (let i = 0; i < items.length; i++) {
            const item = items[i];

            if (!item)
                continue;

            if (item.status === Status.Passive)
                result.push(item);
        }

        return result;
    }
}
