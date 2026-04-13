import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../components"

PopoutWrapper {
    id: root

    popoutWidth: 780

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

    // Форматирование времени (MS -> MM:SS)
    function formatTime(s) {
        if (!s || s < 0) return "00:00";
        let min = Math.floor(s / 60);
        let sec = Math.floor(s % 60);
        return (min < 10 ? "0" + min : min) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 20
        spacing: 24

        // ─── ЛЕВАЯ ЧАСТЬ: Информация и плеер ─────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 320
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
                    text: root.mediaArtist ? (root.mediaArtist + (root.mediaAlbum ? " — " + root.mediaAlbum : "")) : "—"
                    color: "#aaaaaa"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    elide: Text.ElideRight
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
                    value: root.mediaPosition
                    enabled: false // Пока только скелет, без перемотки
                    
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Text {
                text: "Lyrics"
                color: "#888888"
                font { pixelSize: 12; bold: true; letterSpacing: 1 }
                Layout.alignment: Qt.AlignLeft
            }

            ListView {
                id: mediaLyrics
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 12

                model: ListModel {
                    ListElement { line: "I've been counting up"; active: false }
                    ListElement { line: "the times that I"; active: false }
                    ListElement { line: "did you wrong"; active: false }
                    ListElement { line: ""; active: false }
                    ListElement { line: "I just want you"; active: true }
                    ListElement { line: "by my side when"; active: true }
                    ListElement { line: "I get real gone"; active: true }
                }

                delegate: Text {
                    width: parent.width
                    text: model.line
                    color: model.active ? "#ffffff" : "#444444"
                    font { 
                        pixelSize: model.active ? 18 : 16; 
                        bold: model.active 
                    }
                    wrapMode: Text.WordWrap
                    opacity: model.active ? 1.0 : 0.4
                }
            }
        }
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
        if (isOpen) mediaPoller.running = true;
    }
}
