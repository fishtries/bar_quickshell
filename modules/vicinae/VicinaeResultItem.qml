import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconText: "󰍉"
    property string accessoryText: ""
    property color accessoryColor: Theme.info
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
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            color: selected ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)

            AppIcon {
                anchors.centerIn: parent
                text: root.iconText
                color: Theme.textPrimary
                font.pixelSize: 15
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
                    font.pixelSize: 14
                    font.weight: root.selected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.aliasText !== ""
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.08)
                    implicitWidth: aliasLabel.implicitWidth + 10
                    implicitHeight: 18

                    AppText {
                        id: aliasLabel
                        anchors.centerIn: parent
                        text: root.aliasText
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

            AppText {
                Layout.fillWidth: true
                text: root.subtitle
                visible: text !== ""
                color: Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: root.accessoryText !== ""
            Layout.alignment: Qt.AlignVCenter
            radius: 9
            color: Qt.rgba(root.accessoryColor.r, root.accessoryColor.g, root.accessoryColor.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(root.accessoryColor.r, root.accessoryColor.g, root.accessoryColor.b, 0.24)
            implicitWidth: accessoryLabel.implicitWidth + 12
            implicitHeight: 22

            AppText {
                id: accessoryLabel
                anchors.centerIn: parent
                text: root.accessoryText
                color: root.accessoryColor
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
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
