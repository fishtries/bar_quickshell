import QtQuick
import Quickshell
import "../../core"

Item {
    id: root

    property var trayItem: null

    function toggleMenu() {
        if (!menuPopup.menuHandle)
            return;

        if (menuPopup.visible) {
            menuPopup.dismiss();
            return;
        }

        menuPopup.openMenu();
    }

    implicitWidth: 28
    implicitHeight: 28

    TrayMenu {
        id: menuPopup
        menuHandle: root.trayItem && root.trayItem.hasMenu ? root.trayItem.menu : null
        anchorItem: root
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: hoverArea.containsMouse ? Theme.bgHover : "transparent"
        opacity: hoverArea.containsMouse ? 1.0 : 0.0

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: root.trayItem ? root.trayItem.icon : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: hoverArea.containsMouse ? 1.0 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (!root.trayItem)
                return;

            if (mouse.button === Qt.LeftButton) {
                if (root.trayItem.onlyMenu) {
                    root.toggleMenu();
                    return;
                }

                root.trayItem.activate();
                return;
            }

            if (mouse.button === Qt.RightButton && menuPopup.menuHandle)
                root.toggleMenu();
        }
    }
}
