pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/**
 * NotificationState
 * 
 * Global state manager for system notifications.
 * Initializes the NotificationServer D-Bus daemon and provides helpers for UI components.
 */
Item {
    id: root

    signal newNotification(var notification)

    // ─── Presented notification tracking ───────────────────────────────
    // Notifications that have already been shown in the island.
    // Used to prevent re-showing them as cards or cycling through them again.
    property var presentedNotifs: []

    function markPresented(notif) {
        if (notif && !isPresented(notif))
            presentedNotifs = presentedNotifs.concat(notif)
    }

    function isPresented(notif) {
        return presentedNotifs.indexOf(notif) !== -1
    }

    function findNextUnpresented(skipNotif) {
        var items = activeNotifications.values
        if (!items) return null
        for (var i = items.length - 1; i >= 0; i--) {
            if (items[i] !== skipNotif && !isPresented(items[i]))
                return items[i]
        }
        return null
    }

    // Notifications not yet presented in the island (for card stack)
    readonly property var unpresentedNotifications: {
        var items = activeNotifications.values
        if (!items) return []
        var result = []
        for (var i = 0; i < items.length; i++) {
            if (!isPresented(items[i]))
                result.push(items[i])
        }
        return result
    }

    NotificationServer {
        id: notifications
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        // Auto-track every incoming notification so it appears in trackedNotifications
        onNotification: function(notification) {
            notification.tracked = true;
            root.newNotification(notification);
            // Clean stale refs from presentedNotifs (dismissed notifications)
            var items = root.activeNotifications.values
            if (items && root.presentedNotifs && root.presentedNotifs.length > 0) {
                var cleaned = []
                for (var j = 0; j < root.presentedNotifs.length; j++) {
                    if (items.indexOf(root.presentedNotifs[j]) !== -1)
                        cleaned.push(root.presentedNotifs[j])
                }
                root.presentedNotifs = cleaned
            }
        }
    }

    // Expose the tracked notifications model (new API)
    readonly property var activeNotifications: notifications.trackedNotifications

    /**
     * Dismisses all currently tracked notifications.
     * UntypedObjectModel doesn't support .get(), so we dismiss
     * from the onNotification signal cache instead.
     */
    function clearAll() {
        // Dismiss by iterating the model values
        // UntypedObjectModel values can be accessed via QML list iteration
        const items = notifications.trackedNotifications.values;
        if (items) {
            for (let i = items.length - 1; i >= 0; i--) {
                if (items[i]) items[i].dismiss();
            }
        }
    }

    /**
     * Returns the most recent tracked notification object, or null if list is empty.
     */
    function getLatest() {
        const items = notifications.trackedNotifications.values;
        if (items && items.length > 0) {
            return items[items.length - 1];
        }
        return null;
    }
}
