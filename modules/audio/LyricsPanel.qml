import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var controller
    property var lyricsModel: controller ? controller.lyricsModel : null
    readonly property int currentLyricIndex: controller ? controller.currentLyricIndex : -1
    readonly property int revealedCount: controller ? controller.revealedCount : 0
    readonly property bool manualMode: controller ? controller.manualMode : false

    signal seekRequested(real time, int index)

    opacity: (lyricsModel && lyricsModel.count > 0) ? 1.0 : 0.0
    visible: opacity > 0
    spacing: 12

    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    function enterManualMode() {
        if (controller && controller.enterManualMode) {
            controller.enterManualMode();
        }
    }

    function restoreAutoScrollLater() {
        if (controller && controller.restoreAutoScrollLater) {
            controller.restoreAutoScrollLater();
        }
    }

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
        currentIndex: root.manualMode ? -1 : root.currentLyricIndex
        highlightRangeMode: root.manualMode ? ListView.NoHighlightRange : ListView.StrictlyEnforceRange
        preferredHighlightBegin: height * 0.25
        preferredHighlightEnd: height * 0.25

        onDraggingChanged: {
            if (dragging) {
                root.enterManualMode();
            } else if (!flicking) {
                root.restoreAutoScrollLater();
            }
        }

        onFlickingChanged: {
            if (flicking) {
                root.enterManualMode();
            } else if (!dragging) {
                root.restoreAutoScrollLater();
            }
        }

        WheelHandler {
            target: null
            onWheel: event => {
                root.enterManualMode();
                root.restoreAutoScrollLater();
                event.accepted = false;
            }
        }

        model: root.lyricsModel

        delegate: Item {
            id: lyricContainer
            width: ListView.view.width
            height: lyricText.implicitHeight + (isActive ? 28 : 0) + Math.max(0, jellyOffset * 9.15)

            readonly property bool isActive: index === root.currentLyricIndex
            readonly property bool revealed: index < root.revealedCount
            readonly property real viewY: y - ListView.view.contentY + height / 2
            readonly property real focalPoint: ListView.view.height * 0.25
            readonly property real distFromFocal: Math.abs(viewY - focalPoint)
            readonly property real normalizedDist: Math.min(1.0, distFromFocal / (ListView.view.height * 0.55))
            readonly property real bottomFade: Math.max(0.0, Math.min(1.0, (viewY - ListView.view.height * 0.55) / (ListView.view.height * 0.28)))

            property real jellyOffset: 0
            property real jellyTargetOffset: 0
            readonly property int followDelay: {
                const trailingDistance = Math.max(0, index - root.currentLyricIndex);
                if (trailingDistance === 0 || trailingDistance > 10)
                    return 0;

                const headDistance = Math.min(1, trailingDistance);
                const tailDistance = Math.max(0, trailingDistance - 1);
                const headKick = 1 * (1 - Math.exp(-1.15 * headDistance));
                const tailGlide = 1200 * (1 - Math.exp(-0.02 * tailDistance)) + tailDistance * 35;
                const computedDelay = 45 + headKick + tailGlide;
                return Math.min(200 * index, computedDelay);
            }

            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Connections {
                target: root.controller
                function onCurrentLyricIndexChanged() {
                    let trailingDistance = Math.max(0, index - root.currentLyricIndex);
                    if (trailingDistance > 0 && trailingDistance <= 10) {
                        lyricContainer.jellyTargetOffset = Math.min(8, 1 + trailingDistance * 12);
                        settleTimer.stop();
                        followTimer.restart();
                    } else {
                        followTimer.stop();
                        settleTimer.stop();
                        lyricContainer.jellyTargetOffset = 0;
                        lyricContainer.jellyOffset = 0;
                    }
                }
            }

            Behavior on jellyOffset {
                SpringAnimation {
                    spring: 2.2
                    damping: 0.22
                }
            }

            Timer {
                id: followTimer
                interval: lyricContainer.followDelay
                repeat: false
                onTriggered: {
                    lyricContainer.jellyOffset = lyricContainer.jellyTargetOffset;
                    if (lyricContainer.jellyTargetOffset > 0)
                        settleTimer.restart();
                }
            }

            Timer {
                id: settleTimer
                interval: 100
                repeat: false
                onTriggered: lyricContainer.jellyOffset = 0
            }

            TapHandler {
                onTapped: root.seekRequested(model.time, index)
            }

            LyricLineItem {
                id: lyricText
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: lyricContainer.jellyOffset
                lineText: model.line
                isActive: lyricContainer.isActive
                isRevealed: lyricContainer.revealed
                visualOpacity: lyricContainer.viewY < lyricContainer.focalPoint ? Math.max(0.15, 1.0 - lyricContainer.normalizedDist * 2.15) : Math.max(0.0, 1.0 - lyricContainer.bottomFade * lyricContainer.bottomFade)
                visualScale: 1.0
                blurAmount: Math.min(1.0, lyricContainer.normalizedDist * (lyricContainer.viewY < lyricContainer.focalPoint ? 7.5 : 1.5))
            }
        }
    }
}
