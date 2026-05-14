import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../components"
import "../../core"

PopoutWrapper {
    id: root

    enableTearOff: true
    popoutWidth: (lyricsCtrl.lyricsModel && lyricsCtrl.lyricsModel.count > 0) ? 780 : 393
    originX: popoutWidth / 2
    autoClose: false

    LyricsController {
        id: lyricsCtrl
        mediaTitle: MediaState.mediaTitle
        mediaArtist: MediaState.mediaArtist
        mediaPosition: MediaState.mediaPosition
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
                    source: MediaState.mediaArtUrl
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
                    text: MediaState.mediaTitle || "No Media Playing"
                    color: Theme.textPrimary
                    font { pixelSize: 22; bold: true }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    id: trackArtistAlbum
                    text: MediaState.mediaArtist || "—"
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
                    TapHandler { onTapped: MediaState.previous() }
                }

                Text {
                    text: MediaState.mediaStatus === "Playing" ? "\udb80\udfe4" : "\udb81\udc0a" // Pause : Play
                    color: playHover.hovered ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 38
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: playHover }
                    TapHandler { onTapped: MediaState.playPause() }
                }

                Text {
                    text: "\udb81\udcad" // Next
                    color: nextHover.hovered ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 28
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: nextHover }
                    TapHandler { onTapped: MediaState.next() }
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
                    to: MediaState.mediaLength > 0 ? MediaState.mediaLength : 100
                    value: pressed ? value : MediaState.mediaPosition
                    enabled: MediaState.mediaStatus !== "Stopped"
                    
                    onMoved: {
                        MediaState.seek(value);
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
                        text: lyricsCtrl.formatTime(MediaState.mediaPosition)
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: lyricsCtrl.formatTime(MediaState.mediaLength)
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ─── ПРАВАЯ ЧАСТЬ: Текст песен (Lyrics) ──────────────────────────
        LyricsPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            controller: lyricsCtrl

            onSeekRequested: (time, index) => {
                MediaState.seek(time);
                MediaState.mediaPosition = time;
                lyricsCtrl.seekToIndex(index, time);
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            MediaState.poll();
        }
    }
}
