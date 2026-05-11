import QtQuick
import "../../core"

QtObject {
    id: root

    signal requestControlCenter()

    property var _currentNotification: null
    property var _queue: []
    property bool _expanded: false
    property bool _hovered: false

    readonly property bool hasNotification: _currentNotification !== null
    readonly property bool isExpanded: _expanded
    readonly property string visualState: !hasNotification ? "hidden" : _expanded ? "expanded" : "compact"
    readonly property string iconText: "\uf0f3"
    readonly property string appLabel: _currentNotification && _currentNotification.appName ? _currentNotification.appName : "Notification"
    readonly property string summaryLabel: _currentNotification && _currentNotification.summary ? _currentNotification.summary : appLabel
    readonly property string bodyLabel: _currentNotification && _currentNotification.body ? _currentNotification.body : ""

    property Connections _notificationConnections: Connections {
        target: NotificationState
        function onNewNotification(notification) {
            root._handleNewNotification(notification)
        }
        function onActiveNotificationListChanged(notifications) {
            root._syncActiveNotifications(notifications)
        }
    }

    property Timer _expandTimer: Timer {
        interval: AnimationConfig.timerIslandExpand
        repeat: false
        onTriggered: {
            if (root.visualState === "compact") {
                root._expanded = true
                stop()
            }
        }
    }

    property Timer _autoHideTimer: Timer {
        interval: AnimationConfig.timerIslandAutoHide
        repeat: false
        onTriggered: root._dismissCurrentNotification()
    }

    function _activeNotifications() {
        if (NotificationState.activeNotificationValues)
            return NotificationState.activeNotificationValues()

        const items = NotificationState.activeNotifications.values
        var result = []
        if (!items)
            return result

        for (var i = 0; i < items.length; i++)
            result.push(items[i])

        return result
    }

    function _queueContains(notification) {
        return _queue.indexOf(notification) !== -1
    }

    function _setQueue(queue) {
        _queue = queue
    }

    function _cleanQueue(items, skipNotification) {
        var nextQueue = []
        for (var i = 0; i < _queue.length; i++) {
            var notification = _queue[i]
            if (!notification || notification === skipNotification || notification === _currentNotification)
                continue
            if (items.indexOf(notification) === -1)
                continue
            if (nextQueue.indexOf(notification) !== -1)
                continue
            nextQueue.push(notification)
        }
        _setQueue(nextQueue)
    }

    function _showNotification(notification) {
        if (!notification)
            return

        _currentNotification = notification
        _expanded = false
        _expandTimer.stop()
        _autoHideTimer.stop()
        _refreshCurrentNotification(true)
    }

    function _showNextNotification(skipNotification) {
        var items = _activeNotifications()
        _cleanQueue(items, skipNotification)

        var nextNotification = null
        var nextQueue = _queue.slice()
        while (nextQueue.length > 0 && !nextNotification) {
            var queuedNotification = nextQueue.shift()
            if (queuedNotification && queuedNotification !== skipNotification && items.indexOf(queuedNotification) !== -1)
                nextNotification = queuedNotification
        }
        _setQueue(nextQueue)

        if (!nextNotification) {
            for (var i = items.length - 1; i >= 0; i--) {
                if (items[i] && items[i] !== skipNotification) {
                    nextNotification = items[i]
                    break
                }
            }
        }

        if (nextNotification) {
            _showNotification(nextNotification)
        } else {
            _clearCurrentNotification()
        }
    }

    function _clearCurrentNotification() {
        _currentNotification = null
        _expanded = false
        _expandTimer.stop()
        _autoHideTimer.stop()
    }

    function _handleNewNotification(notification) {
        if (!notification)
            return

        if (!_currentNotification) {
            _showNotification(notification)
            return
        }

        if (notification !== _currentNotification && !_queueContains(notification))
            _setQueue(_queue.concat(notification))

        _syncActiveNotifications(_activeNotifications())
    }

    function _syncActiveNotifications(notifications) {
        var items = notifications || _activeNotifications()
        _cleanQueue(items, null)

        if (items.length === 0) {
            _setQueue([])
            _clearCurrentNotification()
            return
        }

        if (_currentNotification && items.indexOf(_currentNotification) === -1) {
            var removedNotification = _currentNotification
            _clearCurrentNotification()
            _showNextNotification(removedNotification)
        }
    }

    function _refreshCurrentNotification(isNewArrival) {
        if (!hasNotification) {
            _clearCurrentNotification()
            return
        }

        if (isNewArrival)
            _expanded = false

        if (_hovered) {
            _autoHideTimer.stop()
            if (!_expanded)
                _expandTimer.restart()
        } else {
            _expandTimer.stop()
            _restartAutoHide()
        }
    }

    function _restartAutoHide() {
        _autoHideTimer.stop()
        if (hasNotification && !_hovered)
            _autoHideTimer.start()
    }

    function handleHover(hovered) {
        _hovered = hovered
        if (!hasNotification) {
            _expandTimer.stop()
            _autoHideTimer.stop()
            return
        }

        if (_hovered) {
            _autoHideTimer.stop()
            if (!_expanded)
                _expandTimer.restart()
        } else {
            _expandTimer.stop()
            _restartAutoHide()
        }
    }

    function _dismissCurrentNotification() {
        var dismissedNotification = _currentNotification
        if (!dismissedNotification)
            return

        _clearCurrentNotification()
        try {
            if (typeof dismissedNotification.dismiss === "function")
                dismissedNotification.dismiss()
        } catch (e) {
        }
        _showNextNotification(dismissedNotification)
    }

    function _invokeCurrentNotification() {
        if (!_currentNotification)
            return

        try {
            if (typeof _currentNotification.invokeDefaultAction === "function")
                _currentNotification.invokeDefaultAction()
        } catch (e) {
        }
    }

    function handleClick() {
        if (!_currentNotification)
            return

        if (visualState === "compact") {
            requestControlCenter()
            _dismissCurrentNotification()
            return
        }

        if (visualState === "expanded") {
            _invokeCurrentNotification()
            _dismissCurrentNotification()
        }
    }

    Component.onCompleted: _syncActiveNotifications(_activeNotifications())
}
