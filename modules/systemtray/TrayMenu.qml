import QtQuick
import Quickshell
import "../../core"

PopupWindow {
    id: root

    property var menuHandle: null
    property Item anchorItem: null
    property Item maskItem: menuFrame

    readonly property int popupGap: 8
    readonly property int menuWidth: 220

    property real contentOpacity: 0.0
    property real contentOffsetY: -8

    color: "transparent"
    grabFocus: true
    implicitWidth: menuFrame.implicitWidth
    implicitHeight: menuFrame.implicitHeight
    mask: Region {
        item: menuFrame
    }

    anchor {
        item: root.anchorItem
        rect.x: 0
        rect.y: root.anchorItem ? root.anchorItem.height + root.popupGap : 0
        rect.width: 1
        rect.height: 1
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.menuHandle
    }

    function openMenu() {
        if (!root.menuHandle || !root.anchorItem)
            return;

        anchor.updateAnchor();
        root.visible = true;
    }

    function dismiss() {
        root.visible = false;
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
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: menuFrame
        anchors.fill: parent
        implicitWidth: root.menuWidth
        implicitHeight: menuColumn.implicitHeight + Theme.spacingSmall * 2
        radius: Theme.radiusPopout
        color: Theme.bgPopout
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        opacity: root.contentOpacity
        transform: Translate {
            y: root.contentOffsetY
        }

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingSmall
            anchors.bottomMargin: Theme.spacingSmall
            spacing: 0

            Repeater {
                model: menuOpener.children ? menuOpener.children.values : []

                delegate: TrayMenuEntry {
                    menuEntry: modelData
                    menuWidth: root.menuWidth
                    menuPopup: root
                }
            }
        }
    }
}
