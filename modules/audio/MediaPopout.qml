import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../components"

PopoutWrapper {
    id: root

    popoutWidth: (mediaLyrics.model && mediaLyrics.model.count > 0) ? 780 : 393
    originX: popoutWidth / 2
    autoClose: false

    // ─── Данные медиа ──────────────────────────────────────────────────
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property string mediaStatus: "Stopped"  // "Playing" | "Paused" | "Stopped"
    property string mediaArtUrl: ""
    property string mediaPlayer: ""
    
    // Новые свойства для прогресса
    property real mediaLength: 0
    property real mediaPosition: 0
    property int currentLyricIndex: -1
    property bool manualMode: false
    property int revealedCount: 0

    Timer {
        id: restoreAutoScrollTimer
        interval: 3000 // 3 секунды
        repeat: false
        onTriggered: root.manualMode = false
    }

    // Функция для очистки названий (удаление feat, Remastered и т.д.)
    function cleanMetadata(text) {
        if (!text) return "";
        return text.replace(/\(feat\..*?\)/gi, "")
                   .replace(/\(with.*?\)/gi, "")
                   .replace(/\[.*?\]/g, "")
                   .replace(/\(.*?\)/g, "")
                   .replace(/- .*?(Remaster|Live|Single|Version|Edit).*/gi, "")
                   .trim();
    }

    // Форматирование времени (MS -> MM:SS)
    function formatTime(s) {
        if (!s || s < 0) return "00:00";
        let min = Math.floor(s / 60);
        let sec = Math.floor(s % 60);
        return (min < 10 ? "0" + min : min) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    // Таймер каскадного появления строк (эффект «волны»)
    Timer {
        id: revealTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (root.revealedCount < lyricsModel.count) {
                root.revealedCount++;
            } else {
                revealTimer.stop();
            }
        }
    }

    function startReveal() {
        root.revealedCount = 0;
        revealTimer.restart();
    }



    function fetchLyrics() {
        let cleanArtist = cleanMetadata(root.mediaArtist);
        let cleanTitle = cleanMetadata(root.mediaTitle);
        
        if (!cleanArtist || !cleanTitle) return;

        let url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(cleanArtist) + "&track_name=" + encodeURIComponent(cleanTitle);
        
        console.log("Fetching lyrics: " + cleanArtist + " - " + cleanTitle);
        
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    let json = JSON.parse(xhr.responseText);
                    lyricsModel.clear();
                    root.revealedCount = 0;
                    
                    if (json.syncedLyrics) {
                        let lines = json.syncedLyrics.split('\n');
                        for (let i = 0; i < lines.length; i++) {
                            let line = lines[i].trim();
                            // Поддержка [mm:ss.xx], [mm:ss.xxx], [mm:ss]
                            let match = line.match(/\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)/);
                            if (match) {
                                let min = parseInt(match[1]);
                                let sec = parseFloat(match[2]);
                                lyricsModel.append({ "time": min * 60 + sec, "line": match[3] });
                            }
                        }
                    } else if (json.plainLyrics) {
                        // Фаллбэк на обычный текст
                        let lines = json.plainLyrics.split('\n');
                        for (let i = 0; i < lines.length; i++) {
                            if (lines[i].trim()) {
                                lyricsModel.append({ "time": 0, "line": lines[i].trim() });
                            }
                        }
                    }
                    // Запускаем каскадное появление
                    startReveal();
                } else {
                    console.log("Lyrics not found for: " + cleanArtist + " - " + cleanTitle);
                    lyricsModel.clear();
                    root.revealedCount = 0;
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    Timer {
        id: lyricsDebounceTimer
        interval: 300
        repeat: false
        onTriggered: fetchLyrics()
    }

    onMediaTitleChanged: { 
        if (mediaTitle) {
            lyricsModel.clear();
            root.revealedCount = 0;
            root.currentLyricIndex = -1;
            lyricsDebounceTimer.restart(); 
            root.manualMode = false; // Сброс при смене трека
        }
    }

    onMediaArtistChanged: {
        if (mediaArtist) {
            lyricsModel.clear();
            root.revealedCount = 0;
            root.currentLyricIndex = -1;
            lyricsDebounceTimer.restart();
        }
    }

    onMediaPositionChanged: updateSync()

    function updateSync() {
        let newIndex = -1;
        for (let i = 0; i < lyricsModel.count; i++) {
            if (lyricsModel.get(i).time <= root.mediaPosition) {
                newIndex = i;
            } else {
                break;
            }
        }
        if (newIndex !== root.currentLyricIndex) {
            root.currentLyricIndex = newIndex;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 20
        spacing: 24

        // ─── ЛЕВАЯ ЧАСТЬ: Информация и плеер ─────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 320
            Layout.minimumWidth: 320
            Layout.maximumWidth: 320
            Layout.fillHeight: true
            spacing: 12

            // Обложка (Квадратная)
            Rectangle {
                id: coverArtWrapper
                implicitWidth: 320
                implicitHeight: 320
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                clip: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: root.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    smooth: true
                }

                // Заглушка, если нет обложки
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: !albumArt.visible
                    Text {
                        anchors.centerIn: parent
                        text: "\udb81\udcf6"
                        color: Qt.rgba(1, 1, 1, 0.1)
                        font.pixelSize: 80
                    }
                }
            }

            // Название и автор
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Text {
                    id: trackTitle
                    text: root.mediaTitle || "No Media Playing"
                    color: "#ffffff"
                    font { pixelSize: 22; bold: true }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    id: trackArtistAlbum
                    text: root.mediaArtist || "—"
                    color: "#aaaaaa"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Кнопки управления
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 40
                
                Text {
                    text: "\udb81\udcae" // Prev
                    color: prevHover.hovered ? "#ffffff" : "#888888"
                    font.pixelSize: 28
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: prevHover }
                    TapHandler { onTapped: prevProc.running = true }
                }

                Text {
                    text: root.mediaStatus === "Playing" ? "\udb80\udfe4" : "\udb81\udc0a" // Pause : Play
                    color: playHover.hovered ? "#ffffff" : "#888888"
                    font.pixelSize: 38
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: playHover }
                    TapHandler { onTapped: playPauseProc.running = true }
                }

                Text {
                    text: "\udb81\udcad" // Next
                    color: nextHover.hovered ? "#ffffff" : "#888888"
                    font.pixelSize: 28
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: nextHover }
                    TapHandler { onTapped: nextProc.running = true }
                }
            }

            // Прогресс-бар (Slider)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: root.mediaLength > 0 ? root.mediaLength : 100
                    value: pressed ? value : root.mediaPosition
                    enabled: root.mediaStatus !== "Stopped"
                    
                    onMoved: {
                        seekProc.command = ["playerctl", "-p", root.mediaPlayer || "spotify,firefox,%any", "position", String(Math.floor(value))];
                        seekProc.running = true;
                    }
                    
                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: progressSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#ffffff"
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: "#ffffff"
                    }
                }

                // Таймстампы
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: root.formatTime(root.mediaPosition)
                        color: "#888888"
                        font.pixelSize: 11
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: root.formatTime(root.mediaLength)
                        color: "#888888"
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ─── ПРАВАЯ ЧАСТЬ: Текст песен (Lyrics) ──────────────────────────
        ColumnLayout {
            opacity: (mediaLyrics.model && mediaLyrics.model.count > 0) ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ListView {
                id: mediaLyrics
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                clip: true
                spacing: 8
                highlightMoveDuration: 600
                highlightMoveVelocity: -1
                currentIndex: root.currentLyricIndex
                highlightRangeMode: root.manualMode ? ListView.NoHighlightRange : ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.25
                preferredHighlightEnd: height * 0.25

                onMovementStarted: {
                    root.manualMode = true;
                    restoreAutoScrollTimer.restart();
                }

                model: ListModel { id: lyricsModel }

                delegate: Item {
                    id: lyricContainer
                    width: ListView.view.width
                    height: lyricText.implicitHeight + (isActive ? 28 : 0)
                    
                    readonly property bool isActive: index === root.currentLyricIndex
                    readonly property bool revealed: index < root.revealedCount
                    
                    // ─── Позиция в видимой зоне ───────────────────────
                    // Центр делегата относительно вьюпорта
                    readonly property real viewY: y - ListView.view.contentY + height / 2
                    // Фокусная точка (совпадает с preferredHighlightBegin)
                    readonly property real focalPoint: ListView.view.height * 0.25
                    // Расстояние от фокуса (0 = в центре, 1 = у края)
                    readonly property real distFromFocal: Math.abs(viewY - focalPoint)
                    readonly property real normalizedDist: Math.min(1.0, distFromFocal / (ListView.view.height * 0.55))
                    
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                    // ─── Jelly-эффект (пружинистая инерция) ────────────
                    property real jellyOffset: 0

                    Connections {
                        target: root
                        function onCurrentLyricIndexChanged() {
                            // Подтолкнуть строки пропорционально расстоянию
                            let diff = index - root.currentLyricIndex;
                            lyricContainer.jellyOffset = diff * 8;
                        }
                    }

                    Behavior on jellyOffset {
                        SpringAnimation {
                            spring: 3
                            damping: 0.35
                        }
                    }

                    Text {
                        id: lyricText
                        width: parent.width - 40
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: lyricContainer.jellyOffset
                        text: model.line
                        
                        // --- Начальное появление (загрузка) ---
                        property real slideOffset: lyricContainer.revealed ? 0 : 40
                        transform: Translate { y: lyricText.slideOffset }
                        Behavior on slideOffset { 
                            NumberAnimation { duration: 500; easing.type: Easing.OutQuart } 
                        }
                        
                        // --- Плавное появление при reveal ---
                        property real revealOpacity: lyricContainer.revealed ? 1.0 : 0.0
                        Behavior on revealOpacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        
                        color: lyricContainer.isActive ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                        font {
                            pixelSize: lyricContainer.isActive ? 18 : 16
                            bold: lyricContainer.isActive
                        }
                        wrapMode: Text.WordWrap
                        
                        // Визуалы привязаны к позиции на экране, а не к индексу
                        opacity: revealOpacity * Math.max(0.15, 1.0 - lyricContainer.normalizedDist * 0.85)
                        scale: Math.max(0.92, 1.0 - lyricContainer.normalizedDist * 0.08)
                        transformOrigin: Item.Left
                        
                        Behavior on color { ColorAnimation { duration: 300 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: !lyricContainer.isActive
                            blurMax: 24
                            blur: Math.min(1.0, lyricContainer.normalizedDist * (lyricContainer.viewY < lyricContainer.focalPoint ? 7.5 : 1.5))
                        }
                    }
                }
            }
        }
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
        running: root.isOpen
        repeat: true
        onTriggered: mediaPoller.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            mediaPoller.running = true;
            // Принудительно запускаем волну при каждом открытии попаута
            if (lyricsModel.count > 0) {
                root.revealedCount = 0;
                revealTimer.restart();
            }
        }
    }
}
