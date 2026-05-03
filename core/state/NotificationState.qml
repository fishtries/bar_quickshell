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
    property var stackNotifications: []
    property int stackRevision: 0
    property var notificationRefs: []
    property var notificationIds: []
    property int nextNotificationId: 1

    function markPresented(notif) {
        if (notif && !isPresented(notif))
            presentedNotifs = presentedNotifs.concat(notif)
    }

    function isPresented(notif) {
        return presentedNotifs.indexOf(notif) !== -1
    }

    function notificationUid(notif) {
        if (!notif)
            return 0

        var index = notificationRefs.indexOf(notif)
        if (index !== -1)
            return notificationIds[index]

        var uid = nextNotificationId
        nextNotificationId += 1
        notificationRefs = notificationRefs.concat(notif)
        notificationIds = notificationIds.concat(uid)
        return uid
    }

    function syncNotificationRefs() {
        var items = activeNotifications.values
        if (!items)
            items = []

        var cleanedPresented = []
        for (var i = 0; i < presentedNotifs.length; i++) {
            if (items.indexOf(presentedNotifs[i]) !== -1)
                cleanedPresented.push(presentedNotifs[i])
        }
        presentedNotifs = cleanedPresented

        var cleanedRefs = []
        var cleanedIds = []
        for (var j = 0; j < notificationRefs.length; j++) {
            if (items.indexOf(notificationRefs[j]) !== -1) {
                cleanedRefs.push(notificationRefs[j])
                cleanedIds.push(notificationIds[j])
            }
        }
        notificationRefs = cleanedRefs
        notificationIds = cleanedIds

        var cleanedStack = []
        for (var k = 0; k < stackNotifications.length; k++) {
            if (items.indexOf(stackNotifications[k]) !== -1)
                cleanedStack.push(stackNotifications[k])
        }
        if (cleanedStack.length !== stackNotifications.length) {
            stackNotifications = cleanedStack
            stackRevision += 1
        }
    }

    function pushStackNotification(notif) {
        if (!notif || stackNotifications.indexOf(notif) !== -1)
            return

        notificationUid(notif)
        stackNotifications = stackNotifications.concat(notif)
        stackRevision += 1
    }

    function removeStackNotification(notif) {
        var index = stackNotifications.indexOf(notif)
        if (index === -1)
            return

        var next = stackNotifications.slice()
        next.splice(index, 1)
        stackNotifications = next
        stackRevision += 1
    }

    function takeNextStackNotification() {
        if (stackNotifications.length === 0)
            return null

        var notification = stackNotifications[0]
        var next = stackNotifications.slice(1)
        stackNotifications = next
        stackRevision += 1
        return notification
    }

    function clearStackNotifications() {
        if (stackNotifications.length === 0)
            return

        stackNotifications = []
        stackRevision += 1
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
        inlineReplySupported: true
        imageSupported: true

        // Auto-track every incoming notification so it appears in trackedNotifications
        onNotification: function(notification) {
            notification.tracked = true;
            root.syncNotificationRefs()
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
