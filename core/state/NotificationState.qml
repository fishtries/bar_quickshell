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

    NotificationServer {
        id: notifications
    }

    // Expose the active notifications model
    readonly property var activeNotifications: notifications.notifications

    /**
     * Closes all currently active notifications.
     */
    function clearAll() {
        const count = notifications.notifications.rowCount();
        for (let i = count - 1; i >= 0; i--) {
            const notification = notifications.notifications.get(i);
            if (notification) {
                notification.close();
            }
        }
    }

    /**
     * Returns the most recent notification object, or null if list is empty.
     */
    function getLatest() {
        const count = notifications.notifications.rowCount();
        if (count > 0) {
            return notifications.notifications.get(count - 1);
        }
        return null;
    }
}
