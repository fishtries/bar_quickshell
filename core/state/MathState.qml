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
    property int totalChars: 0
    property int totalFormulas: 0
    property int sessionsCompleted: 0
    property int streakDays: 0
    property string lastSessionDate: ""
    property var recentSessions: []
    property int averageCharsPerSession: root.sessionsCompleted > 0 ? Math.round(root.totalChars / root.sessionsCompleted) : 0

    property bool popoutOpen: false

    function refresh() {
        validatorPoller.running = true;
        statsReader.running = true;
    }

    function resetSessionState() {
        root.isActive = false;
        root.progress = 0.0;
        root.isReady = false;
        root.addedSymbols = 0;
    }

    function applyStats(stats) {
        root.totalChars = stats.total_chars !== undefined ? stats.total_chars : 0;
        root.totalFormulas = stats.total_formulas !== undefined ? stats.total_formulas : 0;
        root.sessionsCompleted = stats.sessions_completed !== undefined ? stats.sessions_completed : 0;
        root.streakDays = stats.streak_days !== undefined ? stats.streak_days : 0;
        root.lastSessionDate = stats.last_session_date !== undefined ? stats.last_session_date : "";
        root.recentSessions = stats.recent_sessions !== undefined && Array.isArray(stats.recent_sessions) ? stats.recent_sessions : [];
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
                        root.resetSessionState();
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

    Process {
        id: statsReader
        command: ["python", "/home/fish/.config/quickshell/scripts/math_validator.py", "--stats"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (!parsed.error) {
                        root.applyStats(parsed);
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
        onExited: (code, status) => {
            validatorPoller.running = true;
            statsReader.running = true;
        }
    }

    Process {
        id: endSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/scripts/math_control.sh", "stop"]
        onExited: (code, status) => {
            if (code === 0) {
                root.resetSessionState();
            }
            validatorPoller.running = true;
            statsReader.running = true;
        }
    }

    Component.onCompleted: {
        validatorPoller.running = true;
        statsReader.running = true;
    }
}
