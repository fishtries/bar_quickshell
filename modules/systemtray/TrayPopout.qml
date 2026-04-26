import QtQuick
import Quickshell
import "../../core"

PopupWindow {
    id: root

    property Item anchorItem: null
    property Item maskItem: popupFrame

    readonly property int popupGap: 8
    readonly property int popupPadding: Theme.spacingSmall
    readonly property int cellSize: 28
    readonly property int backgroundCount: TrayState.backgroundItems ? TrayState.backgroundItems.length : 0
    readonly property int columnCount: Math.max(1, Math.min(4, backgroundCount))

    property real contentOpacity: 0.0
    property real contentOffsetY: -8

    visible: TrayState.isExpanded && !!root.anchorItem
    color: "transparent"
    implicitWidth: popupFrame.implicitWidth
    implicitHeight: popupFrame.implicitHeight
    mask: Region {
        item: popupFrame
    }

    anchor {
        item: root.anchorItem
        rect.x: 0
        rect.y: root.anchorItem ? root.anchorItem.height + root.popupGap : 0
        rect.width: 1
        rect.height: 1
    }

    onVisibleChanged: {
        if (!visible)
            return;

        anchor.updateAnchor();
        root.contentOpacity = 0.0;
        root.contentOffsetY = -8;
        openAnimation.restart();
    }

    ParallelAnimation {
        id: openAnimation

        NumberAnimation {
            target: root
            property: "contentOpacity"
            from: 0.0
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "contentOffsetY"
            from: -8
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: popupFrame
        anchors.fill: parent
        implicitWidth: root.popupPadding * 2 + Math.max(iconGrid.implicitWidth, root.cellSize)
        implicitHeight: root.popupPadding * 2 + Math.max(iconGrid.implicitHeight, root.cellSize)
        radius: Theme.radiusPopout
        color: Theme.bgPopout
        opacity: root.contentOpacity
        transform: Translate {
            y: root.contentOffsetY
        }

        Grid {
            id: iconGrid
            anchors.centerIn: parent
            columns: root.columnCount
            rowSpacing: Theme.spacingSmall
            columnSpacing: Theme.spacingSmall

            Repeater {
                model: TrayState.backgroundItems

                delegate: TrayIcon {
                    trayItem: modelData
                }
            }
        }
    }
}
