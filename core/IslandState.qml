pragma Singleton
import QtQuick

Item {
    id: root

    property bool isActive: false
    property string sourceModule: ""

    Timer {
        id: resetTimer
        interval: 5000 // Island stays for 5 seconds
        onTriggered: root.isActive = false
    }

    function trigger(source = "screenshot") {
        root.sourceModule = source
        root.isActive = true
        resetTimer.restart()
    }
}
