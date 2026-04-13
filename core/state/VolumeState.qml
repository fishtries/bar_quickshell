pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property real volume: 0.5
    property bool isMuted: false

    function setVolume(val) {
        debounceTimer.targetValue = val
        debounceTimer.restart()
    }

    function toggleMute() {
        toggleMuteProcess.running = true
    }

    Process {
        id: volumePoller
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim()
                if (text.startsWith("Volume:")) {
                    let parts = text.split(" ")
                    if (parts.length >= 2) {
                        let parsedVolume = parseFloat(parts[1])
                        // Обновляем громкость, но если в UI слаш был нажат, UI сам решает, как себя вести.
                        root.volume = parsedVolume
                    }
                    root.isMuted = text.includes("[MUTED]")
                }
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: volumePoller.running = true
    }
    
    Component.onCompleted: volumePoller.running = true

    Process {
        id: setVolumeProcess
        property string targetVol: "0.50"
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVol]
        onExited: volumePoller.running = true
    }

    Timer {
        id: debounceTimer
        interval: 30
        property real targetValue: 0.0
        onTriggered: {
            setVolumeProcess.targetVol = targetValue.toFixed(2)
            setVolumeProcess.running = true
        }
    }

    Process {
        id: toggleMuteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: volumePoller.running = true
    }
}
