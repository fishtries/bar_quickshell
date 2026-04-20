import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Rectangle {
    id: root

    property string textValue: ""
    property string placeholderText: "Search for anything..."
    property bool busy: false
    property alias inputItem: input

    signal textEdited(string value)
    signal keyPressed(int key, int modifiers, var event)

    radius: 22
    color: Qt.rgba(0, 0, 0, 0.94)
    border.width: 1
    border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
    implicitHeight: 60

    Behavior on border.color {
        ColorAnimation {
            duration: AnimationConfig.durationFast
        }
    }

    onTextValueChanged: {
        if (input.text !== textValue)
            input.text = textValue
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        AppIcon {
            text: busy ? "󰔟" : "󰍉"
            color: busy ? Theme.info : Theme.textSecondary
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textPrimary
            selectionColor: Qt.rgba(0.33, 0.8, 1.0, 0.35)
            selectedTextColor: Theme.textPrimary
            font.pixelSize: 20
            clip: true
            selectByMouse: true

            Keys.onPressed: event => {
                root.keyPressed(event.key, event.modifiers, event)
            }

            onTextEdited: root.textEdited(text)

            Component.onCompleted: text = root.textValue

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: root.placeholderText
                color: Theme.textSecondary
                opacity: 0.72
                font.pixelSize: input.font.pixelSize
                visible: input.text.length === 0
            }
        }
    }
}
