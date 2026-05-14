import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../../core"
import "../../components"

Item {
    id: root
    
    property bool isActive: false
    property var activeStandaloneWindow: null
    property bool isSpotifyOpen: MediaState.mediaPlayer === "spotify" && MediaState.mediaStatus !== "Stopped"
    property real currentWidth: isActive ? 80 : (isSpotifyOpen ? 24 : 0)
    property real blurLevel: isActive ? 0.0 : 1.0
    property real iconBlurLevel: isActive ? 1.0 : 0.0

    property bool popoutOpen: false
    property Item popoutItem: mediaPopout
    property Item popoutMaskItem: mediaPopout.maskItem
    property Item popoutParent: null
    property real popoutTopY: 0
    readonly property Item effectivePopoutParent: popoutParent ? popoutParent : root
    readonly property real effectiveWidth: root.width > 0 ? root.width : root.implicitWidth
    readonly property real effectiveHeight: root.height > 0 ? root.height : root.implicitHeight
    property var popoutPosition: Qt.point(0, 0)

    function updatePopoutPosition() {
        const position = root.mapToItem(root.effectivePopoutParent, root.effectiveWidth / 2, 0)
        root.popoutPosition = Qt.point(position.x, root.popoutTopY > 0 ? root.popoutTopY : position.y + root.effectiveHeight + 28)
    }

    onPopoutOpenChanged: {
        if (popoutOpen)
            updatePopoutPosition()
    }

    onEffectiveWidthChanged: updatePopoutPosition()
    onEffectiveHeightChanged: updatePopoutPosition()
    
    implicitWidth: currentWidth
    implicitHeight: 20
    
    opacity: (isActive || isSpotifyOpen) ? 1.0 : 0.0
    
    Behavior on currentWidth { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    Behavior on blurLevel { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    Behavior on iconBlurLevel { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    
    property var values: [0, 0, 0, 0, 0, 0]
    
    Timer {
        id: inactivityTimer
        interval: 2000
        onTriggered: root.isActive = false
    }
    
    Process {
        id: cavaProcess
        command: ["sh", "-c", "cava -p ~/.config/quickshell/modules/audio/cava.conf"]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;
                
                let parts = line.split(';');
                if (parts.length >= 6) {
                    let newVals = [];
                    let hasAudio = false;
                    for (let i = 0; i < 6; i++) {
                        let val = parseInt(parts[i]) || 0;
                        newVals.push(val);
                        if (val > 0) hasAudio = true;
                    }
                    root.values = newVals;
                    
                    if (hasAudio) {
                        root.isActive = true;
                        inactivityTimer.restart();
                    }
                }
            }
        }
    }
    
    Item {
        id: barsContainer
        anchors.fill: parent
        clip: true
        opacity: root.isActive ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 30
            blur: root.blurLevel
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 1
            
            Repeater {
                model: 6
                
                Rectangle {
                    width: 10
                    height: Math.max(4, (root.values[index] / 100) * parent.height)
                    anchors.bottom: parent.bottom
                    color: Theme.foregroundForItem(parent)
                    radius: 2
                    
                    Behavior on height { 
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad } 
                    }
                }
            }
        }
    }

    Item {
        id: iconContainer
        anchors.fill: parent
        opacity: (!root.isActive && root.isSpotifyOpen) ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 30
            blur: root.iconBlurLevel
        }

        Text {
            id: musicIcon
            anchors.centerIn: parent
            text: "\u266A"
            color: Theme.foregroundForItem(musicIcon)
            font.family: Theme.fontIcon
            font.pixelSize: 18
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.popoutOpen = !root.popoutOpen
    }

    MediaPopout {
        id: mediaPopout
        parent: root.effectivePopoutParent
        isOpen: root.popoutOpen
        onCloseRequested: root.popoutOpen = false

        x: root.popoutPosition.x - (width / 2)
        y: root.popoutPosition.y
        z: 1000

        onDetachedDrop: (dropX, dropY) => {
            const globalPos = mediaPopout.mapToGlobal(dropX, dropY);
            let win = standaloneMediaComp.createObject(root, {
                spawnX: globalPos.x,
                spawnY: globalPos.y
            });
            root.activeStandaloneWindow = win;
            mediaPopout.standaloneWindowActive = true;
            win.windowDestroyed.connect(function() {
                root.activeStandaloneWindow = null;
                mediaPopout.standaloneWindowActive = false;
            });
        }
    }

    Component {
        id: standaloneMediaComp
        StandaloneWindow {
            id: standaloneWin
            width: 393
            height: 520

            LyricsController {
                id: standaloneLyricsCtrl
                mediaTitle: MediaState.mediaTitle
                mediaArtist: MediaState.mediaArtist
                mediaPosition: MediaState.mediaPosition
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPopout
                color: Theme.bgPopout
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 320
                        Layout.preferredHeight: 320
                        Layout.alignment: Qt.AlignHCenter
                        radius: 12
                        color: Theme.bgSubtle
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MediaState.mediaArtUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            smooth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: MediaState.mediaTitle || "No Media Playing"
                            color: Theme.textPrimary
                            font { pixelSize: 22; bold: true }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: MediaState.mediaArtist || "—"
                            color: Theme.textSecondary
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 40

                        Text {
                            text: "\udb81\udcae"
                            color: prevHoverSt.hovered ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 28
                            Behavior on color { ColorAnimation { duration: 150 } }
                            HoverHandler { id: prevHoverSt }
                            TapHandler { onTapped: MediaState.previous() }
                        }

                        Text {
                            text: MediaState.mediaStatus === "Playing" ? "\udb80\udfe4" : "\udb81\udc0a"
                            color: playHoverSt.hovered ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 38
                            Behavior on color { ColorAnimation { duration: 150 } }
                            HoverHandler { id: playHoverSt }
                            TapHandler { onTapped: MediaState.playPause() }
                        }

                        Text {
                            text: "\udb81\udcad"
                            color: nextHoverSt.hovered ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 28
                            Behavior on color { ColorAnimation { duration: 150 } }
                            HoverHandler { id: nextHoverSt }
                            TapHandler { onTapped: MediaState.next() }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: MediaState.mediaLength > 0 ? MediaState.mediaLength : 100
                            value: pressed ? value : MediaState.mediaPosition
                            enabled: MediaState.mediaStatus !== "Stopped"
                            onMoved: MediaState.seek(value)

                            background: Rectangle {
                                implicitWidth: 200
                                implicitHeight: 4
                                height: implicitHeight
                                radius: 2
                                color: Theme.bgHover

                                Rectangle {
                                    width: parent.parent.visualPosition * parent.width
                                    height: parent.height
                                    color: Theme.textPrimary
                                    radius: 2
                                }
                            }

                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Theme.textPrimary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: standaloneLyricsCtrl.formatTime(MediaState.mediaPosition)
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: standaloneLyricsCtrl.formatTime(MediaState.mediaLength)
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 16
        running: root.popoutOpen || mediaPopout.isPresented
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updatePopoutPosition()
    }

    Component.onCompleted: updatePopoutPosition()
}
