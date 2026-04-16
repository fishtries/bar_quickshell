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
