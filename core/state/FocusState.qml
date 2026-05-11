pragma Singleton
import QtQml

QtObject {
    id: root

    property int activeRequests: 0
    readonly property bool needsKeyboard: activeRequests > 0

    function request() {
        activeRequests += 1
    }

    function release() {
        activeRequests = Math.max(0, activeRequests - 1)
    }
}
