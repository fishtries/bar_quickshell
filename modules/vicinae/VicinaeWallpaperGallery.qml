import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root

    property var model: null
    property int currentIndex: -1
    property int itemCount: 0
    readonly property real aspectRatio: 21.0 / 9.0
    readonly property int gridMargin: 6
    readonly property int spacing: 10
    readonly property int columns: 3
    readonly property real cellStride: Math.max(1, Math.floor((grid.width - grid.leftMargin - grid.rightMargin) / columns))
    readonly property real tileWidth: Math.max(1, cellStride - spacing)
    readonly property real tileHeight: Math.max(1, Math.floor(tileWidth / aspectRatio))

    signal itemPressed(int index)
    signal itemHovered(int index)
    signal itemActivated(int index)

    function ensureCurrentVisible() {
        if (currentIndex >= 0)
            grid.positionViewAtIndex(currentIndex, GridView.Contain)
    }

    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: root.gridMargin
        clip: true
        model: root.model
        currentIndex: root.currentIndex
        cellWidth: root.cellStride
        cellHeight: root.tileHeight + root.spacing
        leftMargin: 8
        rightMargin: 8
        topMargin: 8
        bottomMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: tile

            required property int index
            required property string title
            required property string launchValue
            required property string previewPath
            required property bool isVideo

            width: root.tileWidth
            height: root.tileHeight
            radius: 16
            color: Theme.bgSubtle
            border.width: root.currentIndex === index ? 2 : 1
            border.color: root.currentIndex === index ? Theme.info : Theme.borderSubtle
            clip: true
            scale: root.currentIndex === index ? 0.985 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: AnimationConfig.durationVeryFast
                    easing.type: AnimationConfig.easingMovement
                }
            }

            Image {
                anchors.fill: parent
                source: tile.previewPath !== "" ? "file://" + tile.previewPath : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
            }

            Rectangle {
                anchors.fill: parent
                color: mouse.containsMouse || root.currentIndex === tile.index ? Qt.rgba(0, 0, 0, 0.12) : "transparent"
            }

            Rectangle {
                visible: tile.isVideo
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                width: 28
                height: 28
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.54)

                AppIcon {
                    anchors.centerIn: parent
                    text: "󰨜"
                    color: Theme.textPrimary
                    font.pixelSize: 15
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.itemHovered(tile.index)
                onClicked: root.itemPressed(tile.index)
                onDoubleClicked: root.itemActivated(tile.index)
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: root.itemCount === 0

        AppIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "󰸉"
            color: Theme.textSecondary
            opacity: 0.75
            font.pixelSize: 30
        }

        AppText {
            Layout.alignment: Qt.AlignHCenter
            text: "No wallpapers"
            color: Theme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }
}
