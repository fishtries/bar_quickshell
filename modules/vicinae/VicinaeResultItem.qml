import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconText: "󰍉"
    property string iconName: ""
    property string accessoryText: ""
    property color accessoryColor: Theme.info
    property string iconColor: Theme.textPrimary
    property string aliasText: ""
    property bool selected: false
    property bool active: false

    signal pressed()
    signal hovered()
    signal activated()

    radius: 14
    color: selected ? Qt.rgba(1, 1, 1, 0.1) : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    implicitHeight: 48

    Behavior on color {
        ColorAnimation {
            duration: AnimationConfig.durationFast
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            color: selected ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)

            Image {
                visible: root.iconName !== ""
                anchors.centerIn: parent
                source: root.iconName !== "" ? "image://icon/" + root.iconName : ""
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            AppIcon {
                visible: root.iconName === ""
                anchors.centerIn: parent
                text: root.iconText
                color: root.iconColor
                font.pixelSize: 18
            }

            Rectangle {
                visible: root.active
                width: 5
                height: 5
                radius: 2.5
                color: Theme.success
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                AppText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            AppText {
                Layout.fillWidth: true
                text: root.subtitle
                visible: text !== ""
                color: Theme.textSecondary
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        // accessoryText removed as per visual cleanup
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered()
        onClicked: {
            root.pressed()
            root.activated()
        }
        onDoubleClicked: root.activated()
    }
}
