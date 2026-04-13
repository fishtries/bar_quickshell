import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../components"

PopoutWrapper {
    id: root

    popoutWidth: 550

    // ─── Данные медиа ──────────────────────────────────────────────────
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property string mediaStatus: "Stopped"  // "Playing" | "Paused" | "Stopped"
    property string mediaArtUrl: ""
    property string mediaPlayer: ""

    // ─── Контент ────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 20

        // Обложка альбома (слева) - сохраняем размеры 268x147
        Rectangle {
            implicitWidth: 268
            implicitHeight: 200
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            clip: true

            // Градиент-фон если нет обложки
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: !albumArt.visible
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.15, 0.1, 0.25, 1.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.15, 0.2, 1.0) }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\udb81\udcf6"
                    color: Qt.rgba(1, 1, 1, 0.15)
                    font.pixelSize: 48
                }
            }

            Image {
                id: albumArt
                anchors.fill: parent
                source: root.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                smooth: true
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        // Правая часть: инфо + управление
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16

            // Информация о треке
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.mediaTitle || "No media playing"
                    color: "#ffffff"
                    font { pixelSize: 16; bold: true }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: root.mediaArtist || "—"
                    color: "#aaaaaa"
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.mediaArtist.length > 0
                }

                Text {
                    text: root.mediaAlbum
                    color: "#777777"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.mediaAlbum.length > 0
                }
            }

            // Кнопки управления
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Предыдущий
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\udb81\udca0"
                        color: "#cccccc"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prevProc.running = true
                    }
                }

                // Плей / Пауза
                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 24
                    color: root.mediaStatus === "Playing"
                        ? Qt.rgba(1, 1, 1, 0.15)
                        : Qt.rgba(1, 1, 1, 0.1)
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.mediaStatus === "Playing" ? "\udb80\udfe4" : "\udb80\udfe8"
                        color: "#ffffff"
                        font.pixelSize: 24
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: playPauseProc.running = true
                    }
                }

                // Следующий
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\udb81\udca1"
                        color: "#cccccc"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nextProc.running = true
                    }
                }
            }

            // Источник
            Text {
                visible: root.mediaPlayer.length > 0
                text: root.mediaPlayer.charAt(0).toUpperCase() + root.mediaPlayer.slice(1)
                color: root.mediaStatus === "Playing" ? "#1DB954" : "#555555" // Spotify green if playing
                font { pixelSize: 11; bold: true }
                Layout.fillWidth: true
            }
        }
    }

    // ─── Управление (playerctl) ─────────────────────────────────────────
    // Используем --player=spotify,firefox,%any чтобы управлять тем же, что видим
    Process {
        id: playPauseProc
        command: ["playerctl", "--player=spotify,firefox,%any", "play-pause"]
        onExited: mediaPoller.running = true
    }

    // ─── Следующий ────────────────────────────────────────────────────────
    Process {
        id: nextProc
        command: ["playerctl", "--player=spotify,firefox,%any", "next"]
        onExited: mediaPoller.running = true
    }

    // ─── Предыдущий ────────────────────────────────────────────────────────
    Process {
        id: prevProc
        command: ["playerctl", "--player=spotify,firefox,%any", "previous"]
        onExited: mediaPoller.running = true
    }

    // ─── Polling: медиа данные ──────────────────────────────────────────
    Process {
        id: mediaPoller
        // Приоритизируем spotify, затем firefox, затем остальные
        command: ["sh", "-c", "playerctl --player=spotify,firefox,%any metadata --format '{{status}}|||{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{playerName}}' 2>/dev/null || echo 'Stopped||||||||||'"]

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|||");
                if (parts.length >= 6) {
                    root.mediaStatus = parts[0] || "Stopped";
                    root.mediaTitle = parts[1] || "";
                    root.mediaArtist = parts[2] || "";
                    root.mediaAlbum = parts[3] || "";
                    root.mediaArtUrl = parts[4] || "";
                    root.mediaPlayer = parts[5] || "";
                } else {
                    root.mediaStatus = "Stopped";
                    root.mediaTitle = "";
                    root.mediaArtist = "";
                    root.mediaAlbum = "";
                    root.mediaArtUrl = "";
                    root.mediaPlayer = "";
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.isOpen
        repeat: true
        onTriggered: mediaPoller.running = true
    }

    onIsOpenChanged: {
        if (isOpen) mediaPoller.running = true;
    }
}
