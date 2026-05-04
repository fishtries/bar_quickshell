pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: root

    readonly property string bridgeScriptPath: "/home/fish/.config/quickshell/scripts/aside_bar_bridge.py"
    readonly property string clientScriptPath: "/home/fish/.config/quickshell/scripts/aside_bar_client.py"

    property bool inputRequested: false
    property bool popoutOpen: false
    property bool bridgeReady: false
    property bool daemonAvailable: false
    property bool awaitingAssistant: false
    property bool forceNewConversation: false
    property string phase: "idle"
    property string modelName: ""
    property string statusName: "idle"
    property string toolName: ""
    property string errorMessage: ""
    property string conversationId: ""
    property real audioLevel: 0.0
    property alias messagesModel: messagesModel

    readonly property bool isBusy: phase === "thinking" || phase === "streaming" || phase === "listening"
    readonly property bool hasConversation: messagesModel.count > 0
    readonly property string shortModelName: shortModel(modelName)
    readonly property string statusText: errorMessage !== "" ? errorMessage : phaseLabel()

    function showIsland(requestKeyboard) {
        islandAutoHideTimer.stop()
        IslandState.showAside()
        if (requestKeyboard === true)
            inputRequested = true
    }

    function scheduleIslandHide() {
        if (IslandState.isAside && !inputRequested && !isBusy)
            islandAutoHideTimer.restart()
    }

    function requestTextInput() {
        errorMessage = ""
        showIsland(true)
    }

    function closeIsland() {
        inputRequested = false
        if (!isBusy)
            IslandState.hide()
    }

    function shortModel(value) {
        let text = (value || "").toString()
        if (text === "")
            return "Aside"
        let slash = text.lastIndexOf("/")
        if (slash >= 0 && slash < text.length - 1)
            text = text.slice(slash + 1)
        return text.replace(/-/g, " ")
    }

    function phaseLabel() {
        if (!daemonAvailable)
            return "daemon offline"
        if (!bridgeReady)
            return "bridge starting"
        if (phase === "listening")
            return "listening"
        if (phase === "thinking")
            return "thinking"
        if (phase === "streaming")
            return "streaming"
        if (statusName === "tool_use" && toolName !== "")
            return "tool: " + toolName
        if (statusName === "speaking")
            return "speaking"
        return "ready"
    }

    function startBridge() {
        if (bridgeProcess.running)
            return
        bridgeReady = false
        bridgeProcess.running = true
    }

    function refreshStatus() {
        if (statusProcess.running)
            return
        statusProcess.command = ["python3", clientScriptPath, "status"]
        statusProcess.running = true
    }

    function processBridgeLine(data) {
        let line = (data || "").trim()
        if (line === "")
            return
        try {
            let payload = JSON.parse(line)
            if (payload.type === "ready") {
                bridgeReady = true
                errorMessage = ""
                return
            }
            if (payload.type === "bridge_error") {
                errorMessage = payload.error || "bridge error"
                phase = "error"
                showIsland(false)
                return
            }
            if (payload.type === "overlay")
                handleOverlayCommand(payload.data || {})
        } catch (error) {
            errorMessage = "bridge parse error"
            phase = "error"
        }
    }

    function processClientLine(data) {
        let line = (data || "").trim()
        if (line === "")
            return
        try {
            let payload = JSON.parse(line)
            if (payload.ok === false) {
                daemonAvailable = false
                errorMessage = payload.error || "aside daemon error"
                phase = "error"
                showIsland(false)
                return
            }
            daemonAvailable = true
            errorMessage = ""
            if (payload.status !== undefined)
                statusName = payload.status || "idle"
            if (payload.tool_name !== undefined)
                toolName = payload.tool_name || ""
            if (payload.model !== undefined)
                modelName = payload.model || ""
        } catch (error) {
            errorMessage = "client parse error"
            phase = "error"
        }
    }

    function handleOverlayCommand(command) {
        let name = command.cmd || ""
        if (name === "open")
            handleOpen(command.mode || "assistant", command.conv_id || "")
        else if (name === "text")
            handleText(command.data || "")
        else if (name === "done")
            handleDone()
        else if (name === "clear")
            handleClear()
        else if (name === "replace")
            handleReplace(command.data || "")
        else if (name === "stream_start")
            handleStreamStart()
        else if (name === "thinking")
            handleThinking()
        else if (name === "listening")
            handleListening()
        else if (name === "audio_level")
            audioLevel = Number(command.data || 0)
        else if (name === "input")
            requestTextInput()
        else if (name === "reply" || name === "convo")
            requestTextInput()
    }

    function handleOpen(mode, convId) {
        if (convId !== "")
            conversationId = convId
        showIsland(false)
        phase = mode === "user" ? "listening" : "streaming"
        errorMessage = ""
        if (awaitingAssistant) {
            ensureAssistantMessage()
            return
        }
        messagesModel.clear()
        appendMessage(mode === "user" ? "user" : "assistant", "")
    }

    function handleText(text) {
        showIsland(false)
        phase = "streaming"
        inputRequested = false
        ensureAssistantMessage()
        let index = messagesModel.count - 1
        messagesModel.setProperty(index, "text", (messagesModel.get(index).text || "") + text)
    }

    function handleReplace(text) {
        showIsland(false)
        if (messagesModel.count === 0)
            appendMessage(phase === "listening" ? "user" : "assistant", text)
        else
            messagesModel.setProperty(messagesModel.count - 1, "text", text)
    }

    function handleDone() {
        awaitingAssistant = false
        phase = "idle"
        audioLevel = 0
        refreshStatus()
        scheduleIslandHide()
    }

    function handleClear() {
        awaitingAssistant = false
        phase = "idle"
        audioLevel = 0
        messagesModel.clear()
        inputRequested = false
        popoutOpen = false
        if (IslandState.isAside)
            IslandState.hide()
        refreshStatus()
    }

    function handleThinking() {
        showIsland(false)
        phase = "thinking"
    }

    function handleListening() {
        showIsland(false)
        phase = "listening"
    }

    function handleStreamStart() {
        showIsland(false)
        phase = "streaming"
        inputRequested = false
        ensureAssistantMessage()
    }

    function appendMessage(role, text) {
        messagesModel.append({"role": role, "text": text || ""})
    }

    function ensureAssistantMessage() {
        if (messagesModel.count === 0 || messagesModel.get(messagesModel.count - 1).role !== "assistant")
            appendMessage("assistant", "")
    }

    function newConversation() {
        messagesModel.clear()
        conversationId = ""
        forceNewConversation = true
        awaitingAssistant = false
        phase = "idle"
        popoutOpen = true
        showIsland(true)
    }

    function sendQuery(text) {
        let trimmed = (text || "").trim()
        if (trimmed === "")
            return
        showIsland(false)
        errorMessage = ""
        phase = "thinking"
        inputRequested = false
        appendMessage("user", trimmed)
        appendMessage("assistant", "")
        awaitingAssistant = true
        let command = ["python3", clientScriptPath, "query", trimmed]
        if (forceNewConversation)
            command.push("--new")
        else if (conversationId !== "")
            command.push("--conversation-id", conversationId)
        forceNewConversation = false
        commandProcess.command = command
        commandProcess.running = true
    }

    function startMic() {
        showIsland(false)
        errorMessage = ""
        phase = "listening"
        inputRequested = false
        let command = ["python3", clientScriptPath, "mic"]
        if (forceNewConversation)
            command.push("--new")
        else if (conversationId !== "")
            command.push("--conversation-id", conversationId)
        forceNewConversation = false
        commandProcess.command = command
        commandProcess.running = true
    }

    function cancel() {
        awaitingAssistant = false
        phase = "idle"
        inputRequested = false
        commandProcess.command = ["python3", clientScriptPath, "cancel"]
        commandProcess.running = true
    }

    function stopTts() {
        commandProcess.command = ["python3", clientScriptPath, "stop-tts"]
        commandProcess.running = true
    }

    function toggleTts() {
        commandProcess.command = ["python3", clientScriptPath, "toggle-tts"]
        commandProcess.running = true
    }

    ListModel {
        id: messagesModel
    }

    Process {
        id: bridgeProcess
        command: ["python3", root.bridgeScriptPath]
        stdout: SplitParser {
            onRead: data => root.processBridgeLine(data)
        }
        onExited: function(code, status) {
            root.bridgeReady = false
            if (code !== 0 && root.errorMessage === "") {
                root.errorMessage = "bridge stopped"
                root.phase = "error"
            }
            bridgeRestartTimer.restart()
        }
    }

    Process {
        id: commandProcess
        command: []
        stdout: SplitParser {
            onRead: data => root.processClientLine(data)
        }
        onExited: function(code, status) {
            root.refreshStatus()
        }
    }

    Process {
        id: statusProcess
        command: []
        stdout: SplitParser {
            onRead: data => root.processClientLine(data)
        }
    }

    Timer {
        id: bridgeRestartTimer
        interval: 2500
        repeat: false
        onTriggered: root.startBridge()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: islandAutoHideTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (IslandState.isAside && !root.inputRequested && !root.isBusy)
                IslandState.hide()
        }
    }

    Connections {
        target: IslandState
        function onSourceModuleChanged() {
            if (!IslandState.isAside)
                root.inputRequested = false
        }
    }

    Component.onCompleted: {
        startBridge()
        refreshStatus()
    }
}
