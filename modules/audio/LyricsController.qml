import QtQuick

QtObject {
    id: controller

    property string mediaTitle: ""
    property string mediaArtist: ""
    property real mediaPosition: 0
    property var activeXhr: null
    property bool destroyed: false
    property int currentLyricIndex: -1
    property bool manualMode: false
    property int revealedCount: 0
    property var lyricsModel: internalLyricsModel

    function cleanMetadata(text) {
        if (!text) return "";
        return text.replace(/\(feat\..*?\)/gi, "")
                   .replace(/\(with.*?\)/gi, "")
                   .replace(/\[.*?\]/g, "")
                   .replace(/\(.*?\)/g, "")
                   .replace(/- .*?(Remaster|Live|Single|Version|Edit).*/gi, "")
                   .trim();
    }

    function formatTime(s) {
        if (!s || s < 0) return "00:00";
        let min = Math.floor(s / 60);
        let sec = Math.floor(s % 60);
        return (min < 10 ? "0" + min : min) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    property Timer restoreAutoScrollTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: controller.manualMode = false
    }

    property Timer revealTimer: Timer {
        interval: 150
        repeat: true
        onTriggered: {
            if (controller.revealedCount < internalLyricsModel.count) {
                controller.revealedCount++;
            } else {
                revealTimer.stop();
            }
        }
    }

    function startReveal() {
        controller.revealedCount = 0;
        revealTimer.restart();
    }

    function enterManualMode() {
        controller.manualMode = true;
        restoreAutoScrollTimer.stop();
    }

    function restoreAutoScrollLater() {
        restoreAutoScrollTimer.restart();
    }

    function abortActiveXhr() {
        if (controller && controller.activeXhr) {
            controller.activeXhr.abort();
            controller.activeXhr = null;
        }
    }

    function fetchLyrics() {
        abortActiveXhr();

        let cleanArtist = cleanMetadata(controller.mediaArtist);
        let cleanTitle = cleanMetadata(controller.mediaTitle);

        if (!cleanArtist || !cleanTitle) return;

        let url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(cleanArtist) + "&track_name=" + encodeURIComponent(cleanTitle);

        console.log("Fetching lyrics: " + cleanArtist + " - " + cleanTitle);

        let xhr = new XMLHttpRequest();
        controller.activeXhr = xhr;
        xhr.onreadystatechange = function() {
            if (!controller || controller.destroyed) return;
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr === controller.activeXhr) controller.activeXhr = null;
                if (xhr.status === 200) {
                    let json = JSON.parse(xhr.responseText);
                    internalLyricsModel.clear();
                    controller.revealedCount = 0;

                    if (json.syncedLyrics) {
                        let lines = json.syncedLyrics.split('\n');
                        for (let i = 0; i < lines.length; i++) {
                            let line = lines[i].trim();
                            let match = line.match(/\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)/);
                            if (match) {
                                let min = parseInt(match[1]);
                                let sec = parseFloat(match[2]);
                                internalLyricsModel.append({ "time": min * 60 + sec, "line": match[3] });
                            }
                        }
                    } else if (json.plainLyrics) {
                        let lines = json.plainLyrics.split('\n');
                        for (let i = 0; i < lines.length; i++) {
                            if (lines[i].trim()) {
                                internalLyricsModel.append({ "time": 0, "line": lines[i].trim() });
                            }
                        }
                    }
                    startReveal();
                } else if (xhr.status !== 0) {
                    console.log("Lyrics not found for: " + cleanArtist + " - " + cleanTitle);
                    internalLyricsModel.clear();
                    controller.revealedCount = 0;
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    property Timer lyricsDebounceTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: fetchLyrics()
    }

    onMediaTitleChanged: {
        abortActiveXhr();
        if (mediaTitle) {
            internalLyricsModel.clear();
            controller.revealedCount = 0;
            controller.currentLyricIndex = -1;
            lyricsDebounceTimer.restart();
            controller.manualMode = false;
        }
    }

    onMediaArtistChanged: {
        abortActiveXhr();
        if (mediaArtist) {
            internalLyricsModel.clear();
            controller.revealedCount = 0;
            controller.currentLyricIndex = -1;
            lyricsDebounceTimer.restart();
        }
    }

    onMediaPositionChanged: updateSync()

    Component.onDestruction: {
        destroyed = true;
        abortActiveXhr();
    }

    function updateSync() {
        let newIndex = -1;
        for (let i = 0; i < internalLyricsModel.count; i++) {
            if (internalLyricsModel.get(i).time <= controller.mediaPosition) {
                newIndex = i;
            } else {
                break;
            }
        }
        if (newIndex !== controller.currentLyricIndex) {
            controller.currentLyricIndex = newIndex;
        }
    }

    function seekToIndex(index, time) {
        controller.currentLyricIndex = index;
    }

    property ListModel internalLyricsModel: ListModel {
    }
}
