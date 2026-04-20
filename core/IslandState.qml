pragma Singleton
import QtQuick

Item {
    id: root

    property bool isActive: false
    property string sourceModule: ""
    property var reminderData: null

    readonly property bool isReminder: root.sourceModule === "reminder"

    signal reminderAutoActionRequested(var reminder)

    Timer {
        id: resetTimer
        interval: root.isReminder ? 60000 : 5000
        onTriggered: {
            if (root.isReminder && root.reminderData) {
                root.reminderAutoActionRequested(root.reminderData)
            } else {
                root.hide()
            }
        }
    }

    function hide() {
        resetTimer.stop()
        root.isActive = false
        root.sourceModule = ""
        root.reminderData = null
    }

    function trigger(source = "screenshot") {
        root.sourceModule = source
        root.reminderData = null
        root.isActive = true
        resetTimer.restart()
    }

    function showReminder(reminder) {
        root.sourceModule = "reminder"
        root.reminderData = reminder
        root.isActive = true
        resetTimer.restart()
    }
}
