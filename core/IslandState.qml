pragma Singleton
import QtQuick

Item {
    id: root

    property bool isActive: false
    property string sourceModule: ""
    property var reminderData: null
    property var transferData: null

    readonly property bool isReminder: root.sourceModule === "reminder"
    readonly property bool isLocalSend: root.sourceModule === "localsend"
    readonly property bool isAside: root.sourceModule === "aside"

    signal reminderAutoActionRequested(var reminder)

    Timer {
        id: resetTimer
        interval: root.isReminder ? 60000 : (root.isAside ? 20000 : 5000)
        onTriggered: {
            if (root.isReminder && root.reminderData) {
                root.reminderAutoActionRequested(root.reminderData)
            } else if (root.isLocalSend && root.transferData && root.transferData.active) {
                resetTimer.stop()
            } else {
                root.hide()
            }
        }
    }

    Timer {
        id: localSendFinishTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root.sourceModule === "success")
                root.hide()
        }
    }

    function hide() {
        resetTimer.stop()
        localSendFinishTimer.stop()
        root.isActive = false
        root.sourceModule = ""
        root.reminderData = null
        root.transferData = null
    }

    function restart() {
        if (root.isActive)
            resetTimer.restart()
    }

    function trigger(source = "screenshot") {
        root.sourceModule = source
        root.reminderData = null
        root.transferData = null
        root.isActive = true
        resetTimer.restart()
    }

    function showReminder(reminder) {
        root.sourceModule = "reminder"
        root.reminderData = reminder
        root.transferData = null
        root.isActive = true
        resetTimer.restart()
    }

    function showLocalSendTransfer(transfer) {
        localSendFinishTimer.stop()
        if (transfer && transfer.active) {
            root.sourceModule = "localsend"
            root.reminderData = null
            root.transferData = transfer
            root.isActive = true
            resetTimer.stop()
        } else if (transfer && transfer.status === "finished") {
            root.sourceModule = "success"
            root.reminderData = null
            root.transferData = null
            root.isActive = true
            resetTimer.stop()
            localSendFinishTimer.restart()
        } else {
            root.sourceModule = "localsend"
            root.reminderData = null
            root.transferData = transfer
            root.isActive = true
            resetTimer.restart()
        }
    }

    function showAside() {
        resetTimer.stop()
        localSendFinishTimer.stop()
        root.sourceModule = "aside"
        root.reminderData = null
        root.transferData = null
        root.isActive = true
    }
}
