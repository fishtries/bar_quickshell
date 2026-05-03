pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: root

    property var devices: []
    property var pendingDevice: null
    property var currentTransfer: ({
        "active": false,
        "direction": "",
        "status": "idle",
        "peer": "",
        "fileName": "",
        "progress": 0,
        "sentBytes": 0,
        "totalBytes": 0,
        "message": ""
    })
    readonly property string scriptPath: "/home/fish/.config/quickshell/modules/localsend/qs-localsend.py"
    readonly property string receiveDirectory: "/home/fish/Downloads/LocalSend"
    readonly property bool receiverRunning: receiveProc.running || root.receiverPortOwnedExternally
    property bool receiverPersistent: true
    property bool receiverStopRequested: false
    property bool receiverPortOwnedExternally: false
    property var pendingReceiveConfirmation: null

    signal scanStarted()
    signal scanFinished()
    signal sendStarted()
    signal sendFinished()
    signal sendFailed(string reason)
    signal transferChanged(var transfer)

    function scan() {
        root.scanStarted()
        scanProc.command = ["python3", root.scriptPath, "scan"]
        scanProc.running = true
    }

    function sendFile(ip, filePath) {
        root.sendFiles({ "ip": ip, "port": 53317, "protocol": "auto", "version": "auto", "name": ip }, [filePath])
    }

    function sendFiles(device, filePaths) {
        if (!device || !filePaths || filePaths.length === 0)
            return

        let command = [
            "python3",
            root.scriptPath,
            "send",
            "--ip",
            device.ip || "",
            "--port",
            String(device.port || 53317),
            "--protocol",
            device.protocol || "auto",
            "--version",
            device.version || "auto",
            "--own-protocol",
            "https",
            "--name",
            device.name || device.alias || device.ip || "Device"
        ]

        for (let i = 0; i < filePaths.length; i++) {
            command.push("--file")
            command.push(filePaths[i])
        }

        root.setTransfer({
            "active": true,
            "direction": "send",
            "status": "preparing",
            "peer": device.name || device.alias || device.ip || "Device",
            "fileName": "",
            "progress": 0,
            "sentBytes": 0,
            "totalBytes": 0,
            "message": ""
        })
        root.sendStarted()
        sendFileProc.command = command
        sendFileProc.running = true
    }

    function pickAndSend(device) {
        if (!device || filePickerProc.running || sendFileProc.running)
            return

        root.pendingDevice = device
        filePickerProc.command = ["python3", root.scriptPath, "pick-files"]
        filePickerProc.running = true
    }

    function startReceiver() {
        root.receiverStopRequested = false
        root.receiverPortOwnedExternally = false
        receiverExternalRetryTimer.stop()
        if (!receiveProc.running)
            receiveProc.running = true
    }

    function stopReceiver() {
        root.receiverStopRequested = true
        root.receiverPortOwnedExternally = false
        receiverRestartTimer.stop()
        receiverExternalRetryTimer.stop()
        if (receiveProc.running)
            receiveProc.running = false
    }

    function confirmReceive(accepted) {
        if (!root.pendingReceiveConfirmation || !root.pendingReceiveConfirmation.id)
            return

        confirmReceiveProc.command = [
            "python3",
            root.scriptPath,
            "confirm-receive",
            "--id",
            root.pendingReceiveConfirmation.id,
            accepted ? "--accept" : "--reject"
        ]
        confirmReceiveProc.running = true

        if (accepted) {
            root.setTransfer({
                "active": true,
                "direction": "receive",
                "status": "waiting",
                "peer": root.pendingReceiveConfirmation.peer || "",
                "fileName": "",
                "progress": 0,
                "sentBytes": 0,
                "totalBytes": root.pendingReceiveConfirmation.totalBytes || 0,
                "message": "Waiting for upload"
            })
        } else {
            root.setTransfer({
                "active": false,
                "direction": "receive",
                "status": "error",
                "peer": root.pendingReceiveConfirmation.peer || "",
                "fileName": "",
                "progress": 0,
                "sentBytes": 0,
                "totalBytes": root.pendingReceiveConfirmation.totalBytes || 0,
                "message": "Incoming transfer rejected"
            })
        }

        root.pendingReceiveConfirmation = null
    }

    function sendClipboard(ip) {
        sendClipProc.command = ["sh", "-c", "wl-paste | localsend-go send --ip " + ip]
        sendClipProc.running = true
    }

    function processScanLine(data) {
        let line = data.trim()
        if (line.length === 0) return

        try {
            let event = JSON.parse(line)
            if (event.type === "device") {
                root.addDevice(event)
            }
            return
        } catch (e) {}

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

    function addDevice(device) {
        if (!device || !device.ip)
            return

        var normalized = {
            "name": device.name || device.alias || device.ip,
            "alias": device.alias || device.name || device.ip,
            "ip": device.ip,
            "port": device.port || 53317,
            "protocol": device.protocol || "auto",
            "version": device.version || "auto",
            "os": device.os || device.deviceType || "unknown",
            "deviceType": device.deviceType || device.os || "unknown",
            "deviceModel": device.deviceModel || "",
            "fingerprint": device.fingerprint || "",
            "download": device.download === true
        }

        for (var i = 0; i < root.devices.length; i++) {
            if (root.devices[i].ip === normalized.ip && root.devices[i].port === normalized.port)
                return
        }

        root.devices = [...root.devices, normalized]
    }

    function setTransfer(transfer) {
        root.currentTransfer = transfer
        IslandState.showLocalSendTransfer(root.currentTransfer)
        root.transferChanged(root.currentTransfer)
    }

    function applyTransferEvent(event) {
        if (!event || !event.type)
            return

        if (event.type === "device") {
            root.addDevice(event)
            return
        }

        if (event.type === "files") {
            root.sendFiles(root.pendingDevice, event.files || [])
            root.pendingDevice = null
            return
        }

        if (event.type === "cancelled") {
            root.pendingDevice = null
            return
        }

        if (event.type === "receiver_started") {
            root.receiverPortOwnedExternally = false
            receiverExternalRetryTimer.stop()
            return
        }

        if (event.type === "receiver_stopped" || event.type === "receiver_takeover" || event.type === "warning")
            return

        if (event.type === "error" && !event.direction && event.message && event.message.indexOf("receive port") >= 0 && event.message.indexOf("already in use") >= 0) {
            root.receiverPortOwnedExternally = true
            if (root.receiverPersistent && !root.receiverStopRequested)
                receiverExternalRetryTimer.restart()
            return
        }

        if (event.type === "incoming_confirmation") {
            root.pendingReceiveConfirmation = event
        }

        let previous = root.currentTransfer || ({})
        let next = {
            "active": previous.active === true,
            "direction": event.direction || previous.direction || "",
            "status": event.status || previous.status || "",
            "peer": event.peer || previous.peer || "",
            "fileName": event.fileName || previous.fileName || "",
            "progress": event.progress !== undefined ? Number(event.progress) : (previous.progress || 0),
            "sentBytes": event.sentBytes !== undefined ? Number(event.sentBytes) : (previous.sentBytes || 0),
            "totalBytes": event.totalBytes !== undefined ? Number(event.totalBytes) : (previous.totalBytes || 0),
            "message": event.message || previous.message || "",
            "fileIndex": event.fileIndex !== undefined ? Number(event.fileIndex) : (previous.fileIndex || 0),
            "fileCount": event.fileCount !== undefined ? Number(event.fileCount) : (previous.fileCount || 0)
        }

        if (event.type === "status" || event.type === "progress" || event.type === "incoming" || event.type === "incoming_confirmation" || event.type === "file_finished")
            next.active = true
        else if (event.type === "finished" || event.type === "error")
            next.active = false

        if (event.type === "error") {
            if (event.direction === "receive")
                root.pendingReceiveConfirmation = null
            next.status = "error"
            next.progress = previous.progress || 0
            root.sendFailed(next.message || "LocalSend failed")
        }

        if (event.type === "finished") {
            next.status = "finished"
            next.progress = 1
            root.sendFinished()
        }

        root.setTransfer(next)
    }

    function processTransferLine(data) {
        let line = data.trim()
        if (line.length === 0)
            return

        try {
            root.applyTransferEvent(JSON.parse(line))
        } catch (e) {}
    }

    Component.onCompleted: {
        if (root.receiverPersistent)
            root.startReceiver()
    }

    Process {
        id: scanProc
        command: ["python3", root.scriptPath, "scan"]

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

        stdout: SplitParser {
            onRead: data => root.processTransferLine(data)
        }

        onExited: (code, status) => {
            if (code !== 0 && root.currentTransfer.status !== "error") {
                root.applyTransferEvent({
                    "type": "error",
                    "direction": "send",
                    "status": "error",
                    "message": "File send exited with code " + code
                })
            }
        }
    }

    Process {
        id: filePickerProc
        command: []

        stdout: SplitParser {
            onRead: data => root.processTransferLine(data)
        }

        onExited: (code, status) => {
            if (code !== 0)
                root.pendingDevice = null
        }
    }

    Process {
        id: receiveProc
        command: ["python3", root.scriptPath, "receive", "--protocol", "https", "--directory", root.receiveDirectory, "--replace-stale-receiver"]

        stdout: SplitParser {
            onRead: data => root.processTransferLine(data)
        }

        onExited: (code, status) => {
            if (root.receiverPersistent && !root.receiverStopRequested) {
                if (root.receiverPortOwnedExternally)
                    receiverExternalRetryTimer.restart()
                else
                    receiverRestartTimer.restart()
            }
        }
    }

    Timer {
        id: receiverRestartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.receiverPersistent && !root.receiverStopRequested && !root.receiverPortOwnedExternally && !receiveProc.running)
                receiveProc.running = true
        }
    }

    Timer {
        id: receiverExternalRetryTimer
        interval: 5000
        repeat: true
        onTriggered: {
            if (root.receiverPersistent && !root.receiverStopRequested && root.receiverPortOwnedExternally && !receiveProc.running) {
                root.receiverPortOwnedExternally = false
                receiveProc.running = true
            }
        }
    }

    Process {
        id: sendClipProc
        command: []

        onExited: (code, status) => {
            if (code !== 0) root.sendFailed("Clipboard send exited with code " + code)
        }
    }

    Process {
        id: confirmReceiveProc
        command: []
    }
}
