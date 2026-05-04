import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../../components"
import "../../core"
import "." as Aside

PopoutWrapper {
    id: root

    property bool needsKeyboard: root.isOpen
    property string draft: ""

    popoutWidth: 460
    autoClose: false
    animateContentResize: true
    contentResizeDuration: AnimationConfig.durationQuick
    contentResizeEasingType: AnimationConfig.easingDefaultInOut

    function submitDraft() {
        let value = input.text.trim()
        if (value === "")
            return
        input.text = ""
        Aside.AsideState.sendQuery(value)
    }

    function actionColor(hovered, active) {
        if (hovered)
            return active ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.22) : Theme.bgHover
        return active ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.14) : Theme.bgSubtle
    }

    onIsOpenChanged: {
        if (isOpen)
            focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: AnimationConfig.durationNormal
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                input.forceActiveFocus()
                input.cursorPosition = input.text.length
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSmall

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 14
            color: Aside.AsideState.isBusy ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.18) : Theme.bgSubtle
            border.color: Aside.AsideState.bridgeReady && Aside.AsideState.daemonAvailable ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.42) : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.42)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: Aside.AsideState.phase === "listening" ? "󰍬" : "󰚩"
                color: Aside.AsideState.isBusy ? Theme.info : Theme.textPrimary
                font.family: Theme.fontIcon
                font.pixelSize: 18
            }

            Rectangle {
                anchors.centerIn: parent
                width: 18 + Math.max(0, Math.min(1, Aside.AsideState.audioLevel)) * 16
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.35)
                border.width: Aside.AsideState.phase === "listening" ? 1 : 0
                opacity: Aside.AsideState.phase === "listening" ? 1 : 0
                Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: "Aside"
                color: Theme.textPrimary
                font.family: Theme.fontPrimary
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: Aside.AsideState.shortModelName + " · " + Aside.AsideState.statusText
                color: Aside.AsideState.errorMessage !== "" ? Theme.warning : Theme.textSecondary
                font.family: Theme.fontPrimary
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Rectangle {
            implicitWidth: newText.implicitWidth + 18
            implicitHeight: 30
            radius: 10
            color: actionColor(newMouse.containsMouse, false)

            Text {
                id: newText
                anchors.centerIn: parent
                text: "New"
                color: Theme.textSecondary
                font.family: Theme.fontPrimary
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                id: newMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Aside.AsideState.newConversation()
            }
        }

        Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: 10
            color: actionColor(micMouse.containsMouse, Aside.AsideState.phase === "listening")

            Text {
                anchors.centerIn: parent
                text: "󰍬"
                color: Aside.AsideState.phase === "listening" ? Theme.info : Theme.textSecondary
                font.family: Theme.fontIcon
                font.pixelSize: 15
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Aside.AsideState.startMic()
            }
        }

        Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: 10
            color: cancelMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.20) : Theme.bgSubtle

            Text {
                anchors.centerIn: parent
                text: "󰓛"
                color: cancelMouse.containsMouse ? Theme.error : Theme.textSecondary
                font.family: Theme.fontIcon
                font.pixelSize: 15
            }

            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Aside.AsideState.cancel()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.borderSubtle
    }

    ScrollView {
        id: chatScroll
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(170, Math.min(420, messagesColumn.implicitHeight + 8))
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: messagesColumn
            width: chatScroll.availableWidth
            spacing: 8

            Item {
                visible: Aside.AsideState.messagesModel.count === 0
                Layout.fillWidth: true
                implicitHeight: 132

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰚩"
                        color: Theme.info
                        font.family: Theme.fontIcon
                        font.pixelSize: 26
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Aside.AsideState.daemonAvailable ? "Ask local Ollama from the bar" : "Start aside daemon to use the assistant"
                        color: Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: 320
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Repeater {
                model: Aside.AsideState.messagesModel

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: messageColumn.implicitHeight + 18
                    radius: 14
                    color: model.role === "user" ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.12) : Theme.bgSubtle
                    border.color: model.role === "user" ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.25) : Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: messageColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: model.role === "user" ? "You" : "Aside"
                                color: model.role === "user" ? Theme.info : Theme.textPrimary
                                font.family: Theme.fontPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: model.role === "assistant" && model.text === "" && Aside.AsideState.isBusy
                                text: "thinking"
                                color: Theme.textSecondary
                                font.family: Theme.fontPrimary
                                font.pixelSize: 11
                            }
                        }

                        TextEdit {
                            Layout.fillWidth: true
                            text: model.text === "" && model.role === "assistant" && Aside.AsideState.isBusy ? "…" : model.text
                            color: model.role === "user" ? Theme.textPrimary : Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 14
                            wrapMode: TextEdit.Wrap
                            readOnly: true
                            selectByMouse: true
                            selectedTextColor: Theme.textDark
                            selectionColor: Theme.info
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 14
        color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Theme.bgSubtle
        border.color: input.activeFocus ? Theme.info : Theme.borderSubtle
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 6
            spacing: 8

            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                font.family: Theme.fontPrimary
                font.pixelSize: 14
                selectByMouse: true
                clip: true
                enabled: Aside.AsideState.daemonAvailable
                Keys.onEscapePressed: root.closeRequested()
                Keys.onReturnPressed: root.submitDraft()
                Keys.onEnterPressed: root.submitDraft()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: Aside.AsideState.daemonAvailable ? "Message Aside…" : "aside daemon is offline"
                    color: Theme.textSecondary
                    font: input.font
                    enabled: false
                    visible: !input.text && !input.preeditText
                }
            }

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 11
                color: sendMouse.containsMouse ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.25) : Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.14)
                opacity: input.text.trim() !== "" && Aside.AsideState.daemonAvailable ? 1 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: "󰒊"
                    color: Theme.info
                    font.family: Theme.fontIcon
                    font.pixelSize: 15
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: input.text.trim() !== "" && Aside.AsideState.daemonAvailable
                    onClicked: root.submitDraft()
                }
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.isOpen && Aside.AsideState.messagesModel.count > 0
        onTriggered: chatScroll.ScrollBar.vertical.position = 1.0
    }
}
