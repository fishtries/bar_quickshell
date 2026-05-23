import QtQuick
import QtQuick.Effects
import "../../core"

Item {
    id: root

    property var items: []
    property int winnerIndex: -1
    property int revision: 0
    property bool active: false
    property int animationDuration: 2000
    property real stripX: width + 40
    property real flashOpacity: 0.0
    readonly property real cardWidth: 260
    readonly property real cardHeight: 148
    readonly property real cardSpacing: 12
    readonly property real itemStride: cardWidth + cardSpacing

    clip: true

    function startRoll() {
        if (!active || width <= 0 || !items || items.length === 0 || winnerIndex < 0)
            return

        rollAnimation.stop()
        flashAnimation.stop()
        const jitter = (Math.random() - 0.5) * Math.max(12, cardWidth * 0.34)
        stripX = width + itemStride
        flashOpacity = 0.0
        rollAnimation.to = width * 0.5 - winnerIndex * itemStride - cardWidth * 0.5 + jitter
        flashAnimation.restart()
        rollAnimation.restart()
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(startRoll)
        else
            rollAnimation.stop()
    }

    onRevisionChanged: {
        if (active)
            Qt.callLater(startRoll)
    }

    onWidthChanged: {
        if (active && !rollAnimation.running)
            Qt.callLater(startRoll)
    }

    NumberAnimation {
        id: rollAnimation
        target: root
        property: "stripX"
        duration: root.animationDuration
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: flashAnimation

        NumberAnimation {
            target: root
            property: "flashOpacity"
            to: 0.82
            duration: 38
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "flashOpacity"
            to: 0.0
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Theme.bgElevated
    }

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: 26
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        id: rouletteLayer
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundedMask
        }

        Item {
            id: viewport
            anchors.fill: parent
            anchors.margins: 12
            clip: true

            Row {
                x: root.stripX
                y: Math.max(0, (viewport.height - root.cardHeight) * 0.5)
                spacing: root.cardSpacing

                Repeater {
                    model: root.items || []

                    delegate: Rectangle {
                        required property var modelData

                        width: root.cardWidth
                        height: root.cardHeight
                        radius: 18
                        color: Theme.bgSubtle
                        border.width: 1
                        border.color: Theme.borderSubtle
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData.previewPath ? "file://" + modelData.previewPath : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            visible: modelData.isVideo === true
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            width: 22
                            height: 22
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.54)
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.top: viewport.top
            anchors.bottom: viewport.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 3
            radius: 2
            color: Theme.info
            opacity: 0.95
        }

        Rectangle {
            anchors.top: viewport.top
            anchors.bottom: viewport.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 26
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(0.33, 0.8, 1.0, 0.0)
                }

                GradientStop {
                    position: 0.5
                    color: Qt.rgba(0.33, 0.8, 1.0, 0.16)
                }

                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0.33, 0.8, 1.0, 0.0)
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: viewport.top
            anchors.bottom: viewport.bottom
            width: 64
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Theme.bgElevated
                }

                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0)
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: viewport.top
            anchors.bottom: viewport.bottom
            width: 64
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(0, 0, 0, 0)
                }

                GradientStop {
                    position: 1.0
                    color: Theme.bgElevated
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 26
            color: "white"
            opacity: root.flashOpacity
            visible: opacity > 0.001
        }
    }
}
