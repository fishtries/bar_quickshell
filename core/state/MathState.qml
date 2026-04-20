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

    // Stats
    property int totalChars: 0
    property int totalFormulas: 0
    property int sessionsCompleted: 0
    property int streakDays: 0
    property string lastSessionDate: ""
    property var historyData: []

    function loadStats() {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        let responseText = xhr.responseText ? xhr.responseText.trim() : "";
                        if (responseText.length > 0) {
                            let parsed = JSON.parse(responseText);
                            root.totalChars = parsed.total_chars || 0;
                            root.totalFormulas = parsed.total_formulas || 0;
                            root.sessionsCompleted = parsed.sessions_completed || 0;
                            root.streakDays = parsed.streak_days || 0;
                            root.lastSessionDate = parsed.last_session_date || "";

                            // Parse history (last 7 days mapping to points)
                            let histObj = parsed.history || {};
                            let hist = [];
                            let maxPts = 7;
                            for (let i = maxPts - 1; i >= 0; i--) {
                                let d = new Date();
                                d.setDate(d.getDate() - i);
                                let y = d.getFullYear();
                                let m = String(d.getMonth() + 1).padStart(2, '0');
                                let day = String(d.getDate()).padStart(2, '0');
                                let dateStr = `${y}-${m}-${day}`;
                                let pts = histObj[dateStr] ? histObj[dateStr].chars : 0;
                                hist.push({ date: dateStr, value: pts });
                            }
                            root.historyData = hist;
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.open("GET", "file:///home/fish/.config/quickshell/data/math_stats.json", true);
        xhr.send();
    }

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
        id: completeProcess
        command: ["python", "/home/fish/.config/quickshell/scripts/math_validator.py", "--complete"]
        onExited: {
            root.loadStats();
        }
    }

    Process {
        id: endSessionProcess
        command: ["bash", "/home/fish/.config/quickshell/scripts/math_control.sh", "stop"]
        onExited: {
            root.isActive = false;
            root.progress = 0.0;
            root.isReady = false;
            root.addedSymbols = 0;
            completeProcess.running = true;
            validatorPoller.running = true;
        }
    }

    Component.onCompleted: {
        validatorPoller.running = true;
        loadStats();
    }
}
