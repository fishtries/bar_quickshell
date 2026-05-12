pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    // ─── Данные медиа ──────────────────────────────────────────────────
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property string mediaStatus: "Stopped"  // "Playing" | "Paused" | "Stopped"
    property string mediaArtUrl: ""
    property string mediaPlayer: ""

    // Свойства для прогресса
    property real mediaLength: 0
    property real mediaPosition: 0

    // ─── Публичные функции ──────────────────────────────────────────────
    function playPause() {
        playPauseProc.running = true
    }

    function next() {
        nextProc.running = true
    }

    function previous() {
        prevProc.running = true
    }

    function seek(position) {
        seekProc.command = ["playerctl", "-p", root.mediaPlayer || "spotify,firefox,%any", "position", String(Math.floor(position))];
        seekProc.running = true;
    }

    function poll() {
        mediaPoller.running = true
    }

    // ─── УПРАВЛЕНИЕ (Processes) ────────────────────────────────────────
    Process {
        id: playPauseProc
        command: ["playerctl", "--player=spotify,firefox,%any", "play-pause"]
        onExited: mediaPoller.running = true
    }

    Process {
        id: nextProc
        command: ["playerctl", "--player=spotify,firefox,%any", "next"]
        onExited: mediaPoller.running = true
    }

    Process {
        id: prevProc
        command: ["playerctl", "--player=spotify,firefox,%any", "previous"]
        onExited: mediaPoller.running = true
    }

    Process {
        id: seekProc
        command: ["playerctl", "position", "0"]
        onExited: mediaPoller.running = true
    }

    // ─── ДАННЫЕ (Playerctl Poller) ──────────────────────────────────────
    Process {
        id: mediaPoller
        command: ["sh", "-c", "playerctl --player=spotify,firefox,%any metadata --format '{{status}}|||{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{playerName}}|||{{mpris:length}}|||{{position}}' 2>/dev/null || echo 'Stopped||||||||||||||'"]

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|||");
                if (parts.length >= 8) {
                    root.mediaStatus = parts[0] || "Stopped";
                    root.mediaTitle = parts[1] || "";
                    root.mediaArtist = parts[2] || "";
                    root.mediaAlbum = parts[3] || "";
                    root.mediaArtUrl = parts[4] || "";
                    root.mediaPlayer = parts[5] || "";

                    // Конвертация микросекунд в секунды
                    let len = parseInt(parts[6]);
                    root.mediaLength = isNaN(len) ? 0 : len / 1000000;

                    let pos = parseInt(parts[7]);
                    root.mediaPosition = isNaN(pos) ? 0 : pos / 1000000;
                } else {
                    root.mediaStatus = "Stopped";
                    root.mediaTitle = "";
                    root.mediaArtist = "";
                    root.mediaAlbum = "";
                    root.mediaArtUrl = "";
                    root.mediaPlayer = "";
                    root.mediaLength = 0;
                    root.mediaPosition = 0;
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: mediaPoller.running = true
    }

    Component.onCompleted: mediaPoller.running = true
}
