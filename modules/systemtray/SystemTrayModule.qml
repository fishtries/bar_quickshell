import QtQuick
import "../../core"

Row {
    id: root

    spacing: 8
    property Item popoutItem: trayPopout.maskItem

    Row {
        id: pinnedItemsRow

        spacing: 8

        Repeater {
            model: TrayState.pinnedItems

            delegate: TrayIcon {
                trayItem: modelData
            }
        }
    }

    Rectangle {
        id: trayToggle

        width: 28
        height: 28
        radius: 8
        color: TrayState.isExpanded || toggleMouse.containsMouse ? Theme.localHoverForItem(trayToggle) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            anchors.centerIn: parent
            text: TrayState.isExpanded ? "▴" : "▾"
            color: TrayState.isExpanded ? Theme.foregroundForItem(parent) : Theme.secondaryForegroundForItem(parent)
            font.family: Theme.fontPrimary
            font.pixelSize: 14
            opacity: toggleMouse.containsMouse || TrayState.isExpanded ? 1.0 : 0.85

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        MouseArea {
            id: toggleMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: TrayState.toggle()
        }
    }

    TrayPopout {
        id: trayPopout

        anchorItem: trayToggle
    }
}
