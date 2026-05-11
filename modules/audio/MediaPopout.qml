import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"
import "../../core"

PopoutWrapper {
    id: root

    popoutWidth: (lyricsCtrl.lyricsModel && lyricsCtrl.lyricsModel.count > 0) ? 780 : 393
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

    LyricsController {
        id: lyricsCtrl
        mediaTitle: root.mediaTitle
        mediaArtist: root.mediaArtist
        mediaPosition: root.mediaPosition
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
                color: Theme.bgSubtle
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
                        color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.1)
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
                    color: Theme.textPrimary
                    font { pixelSize: 22; bold: true }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    id: trackArtistAlbum
                    text: root.mediaArtist || "—"
                    color: Theme.textSecondary
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
                    color: prevHover.hovered ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 28
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: prevHover }
                    TapHandler { onTapped: prevProc.running = true }
                }

                Text {
                    text: root.mediaStatus === "Playing" ? "\udb80\udfe4" : "\udb81\udc0a" // Pause : Play
                    color: playHover.hovered ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 38
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: playHover }
                    TapHandler { onTapped: playPauseProc.running = true }
                }

                Text {
                    text: "\udb81\udcad" // Next
                    color: nextHover.hovered ? Theme.textPrimary : Theme.textSecondary
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
                        color: Theme.bgHover

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            color: Theme.textPrimary
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: Theme.textPrimary
                    }
                }

                // Таймстампы
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: lyricsCtrl.formatTime(root.mediaPosition)
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: lyricsCtrl.formatTime(root.mediaLength)
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ─── ПРАВАЯ ЧАСТЬ: Текст песен (Lyrics) ──────────────────────────
        ColumnLayout {
            opacity: (lyricsCtrl.lyricsModel && lyricsCtrl.lyricsModel.count > 0) ? 1.0 : 0.0
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
                spacing: 16
                highlightMoveDuration: 600
                highlightMoveVelocity: -1
                currentIndex: lyricsCtrl.currentLyricIndex
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.25
                preferredHighlightEnd: height * 0.25

                model: lyricsCtrl.lyricsModel

                delegate: LyricLineItem {
                    x: 20
                    width: ListView.view.width - 40
                    lineText: model.line
                    isActive: index === lyricsCtrl.currentLyricIndex
                    isRevealed: index < lyricsCtrl.revealedCount
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
        }
    }
}
