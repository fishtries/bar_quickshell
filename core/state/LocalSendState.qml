pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var devices: []

    signal scanStarted()
    signal scanFinished()
    signal sendFailed(string reason)

    function scan() {
        scanProc.running = true
    }

    function sendFile(ip, filePath) {
        sendFileProc.command = ["localsend-go", "send", "--ip", ip, "--file", filePath]
        sendFileProc.running = true
    }

    function sendClipboard(ip) {
        sendClipProc.command = ["sh", "-c", "wl-paste | localsend-go send --ip " + ip]
        sendClipProc.running = true
    }

    function processScanLine(data) {
        let line = data.trim()
        if (line.length === 0) return

        // Expected format: name\tip\tos  (tab-separated)
        let parts = line.split("\t")
        if (parts.length >= 2) {
            var device = {
                "name": parts[0],
                "ip": parts[1],
                "os": parts.length >= 3 ? parts[2] : "unknown"
            }

            // Avoid duplicates
            for (var i = 0; i < root.devices.length; i++) {
                if (root.devices[i].ip === device.ip) return
            }

            root.devices = [...root.devices, device]
        }
    }

    Process {
        id: scanProc
        command: ["localsend-go", "scan"]

        stdout: SplitParser {
            onRead: data => root.processScanLine(data)
        }

        onExited: (code, status) => {
            root.scanFinished()
        }
    }

    Process {
        id: sendFileProc
        command: []

        onExited: (code, status) => {
            if (code !== 0) root.sendFailed("File send exited with code " + code)
        }
    }

    Process {
        id: sendClipProc
        command: []

        onExited: (code, status) => {
            if (code !== 0) root.sendFailed("Clipboard send exited with code " + code)
        }
    }
}
