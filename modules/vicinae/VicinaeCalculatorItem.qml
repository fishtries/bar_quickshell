import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Rectangle {
    id: root

    property string question: ""
    property string questionUnit: "Expression"
    property string answer: ""
    property string answerUnit: "Result"
    property bool selected: false

    signal pressed()
    signal hovered()
    signal activated()

    radius: 18
    color: selected ? Qt.rgba(1, 1, 1, 0.1) : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    implicitHeight: 92

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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            AppText {
                Layout.fillWidth: true
                text: root.question
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textPrimary
                font.pixelSize: 22
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            AppText {
                Layout.fillWidth: true
                text: root.questionUnit
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        AppIcon {
            text: "󰁕"
            color: Theme.textSecondary
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            AppText {
                Layout.fillWidth: true
                text: root.answer
                horizontalAlignment: Text.AlignHCenter
                color: Theme.success
                font.pixelSize: 22
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            AppText {
                Layout.fillWidth: true
                text: root.answerUnit
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
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
