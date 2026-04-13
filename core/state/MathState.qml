pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isActive: false
    property real progress: 0.0
    property bool isReady: false
    property int addedSymbols: 0
    property int targetSymbols: 500

    property bool popoutOpen: false

    function refresh() {
        validatorPoller.running = true;
    }

    function startSession() {
        startSessionProcess.running = true;
    }

    function endSession() {
        root.popoutOpen = false;
        endSessionProcess.running = true;
    }

    Process {
        id: validatorPoller
        command: ["python", "/home/fish/.config/quickshell/scripts/math_validator.py", "--check"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.error) {
                        root.isActive = false;
                        root.progress = 0.0;
                        root.isReady = false;
                        root.addedSymbols = 0;
                    } else {
                        root.isActive = true;
                        root.progress = parsed.progress !== undefined ? parsed.progress : 0.0;
                        root.isReady = parsed.is_ready === true;
                        root.addedSymbols = parsed.added_symbols !== undefined ? parsed.added_symbols : 0;
                    }
                } catch(e) { }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: validatorPoller.running = true
    }

    Process {
        id: startSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/scripts/math_control.sh", "start"]
        onExited: validatorPoller.running = true
    }

    Process {
        id: endSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/scripts/math_control.sh", "stop"]
        onExited: {
            root.isActive = false;
            root.progress = 0.0;
            root.isReady = false;
            root.addedSymbols = 0;
            validatorPoller.running = true;
        }
    }

    Component.onCompleted: validatorPoller.running = true
}
