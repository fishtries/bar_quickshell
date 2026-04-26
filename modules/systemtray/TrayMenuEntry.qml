import QtQuick
import Quickshell
import "../../core"

Item {
    id: root

    property var menuEntry: null
    property int depth: 0
    property int menuWidth: 220
    property var menuPopup: null

    readonly property bool isSeparator: root.menuEntry ? root.menuEntry.isSeparator : false
    readonly property bool hasChildren: root.menuEntry ? root.menuEntry.hasChildren : false
    readonly property bool isCheckBox: root.menuEntry ? root.menuEntry.buttonType === QsMenuButtonType.CheckBox : false
    readonly property bool isRadioButton: root.menuEntry ? root.menuEntry.buttonType === QsMenuButtonType.RadioButton : false
    readonly property bool isChecked: root.menuEntry ? root.menuEntry.checkState === Qt.Checked : false

    property bool submenuOpen: false

    implicitWidth: root.menuWidth
    implicitHeight: root.isSeparator ? separatorBlock.implicitHeight : entryBlock.implicitHeight

    QsMenuOpener {
        id: childMenuOpener
        menu: root.hasChildren ? root.menuEntry : null
    }

    Item {
        id: separatorBlock
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.isSeparator
        implicitHeight: Theme.spacingSmall + 1
        height: implicitHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10 + root.depth * 12
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
    }

    Item {
        id: entryBlock
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isSeparator
        implicitHeight: buttonBackground.height + submenuBlock.height
        height: implicitHeight

        Rectangle {
            id: buttonBackground
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            radius: 10
            color: root.submenuOpen ? Theme.bgActive : (buttonMouse.containsMouse ? Theme.bgHover : "transparent")
            opacity: root.menuEntry && root.menuEntry.enabled ? 1.0 : 0.55

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10 + root.depth * 12
                anchors.rightMargin: 10

                Item {
                    id: leadingSlot
                    width: 16
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Image {
                        id: leadingIcon
                        anchors.centerIn: parent
                        visible: root.menuEntry && root.menuEntry.icon !== ""
                        width: 16
                        height: 16
                        source: root.menuEntry ? root.menuEntry.icon : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !leadingIcon.visible && root.isCheckBox && root.isChecked
                        text: "✓"
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !leadingIcon.visible && root.isRadioButton && root.isChecked
                        text: "●"
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 11
                    }
                }

                Text {
                    id: labelText
                    anchors.left: leadingSlot.right
                    anchors.leftMargin: 10
                    anchors.right: childArrow.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.menuEntry ? root.menuEntry.text : ""
                    color: Theme.textPrimary
                    font.family: Theme.fontPrimary
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    id: childArrow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.hasChildren ? implicitWidth : 0
                    visible: root.hasChildren
                    text: "›"
                    color: Theme.textSecondary
                    font.family: Theme.fontPrimary
                    font.pixelSize: 14
                }
            }

            MouseArea {
                id: buttonMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !!root.menuEntry && root.menuEntry.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                onClicked: {
                    if (!root.menuEntry)
                        return;

                    if (root.hasChildren) {
                        root.submenuOpen = !root.submenuOpen;
                        return;
                    }

                    root.menuEntry.triggered();

                    if (root.menuPopup)
                        root.menuPopup.dismiss();
                }
            }
        }

        Item {
            id: submenuBlock
            anchors.top: buttonBackground.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.hasChildren && root.submenuOpen
            height: visible ? submenuColumn.implicitHeight : 0
            implicitHeight: height

            Column {
                id: submenuColumn
                width: parent.width
                spacing: 0

                Repeater {
                    model: childMenuOpener.children ? childMenuOpener.children.values : []

                    delegate: Loader {
                        width: root.menuWidth
                        source: "TrayMenuEntry.qml"
                        onLoaded: {
                            item.menuEntry = modelData;
                            item.depth = root.depth + 1;
                            item.menuWidth = root.menuWidth;
                            item.menuPopup = root.menuPopup;
                        }
                    }
                }
            }
        }
    }
}
