import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../components"
import "../../../core"
import "../../aside" as Aside

Item {
    id: root

    readonly property bool isIsland: IslandState.isActive
    readonly property bool isReminderIsland: IslandState.isReminder
    readonly property bool isAsideIsland: IslandState.isAside
    readonly property bool asideVoiceIsland: root.isAsideIsland && Aside.AsideState.voiceSession
    
    // Smooth morphing dimensions
    readonly property int requestedWidth: root.asideVoiceIsland ? 540 : 720
    readonly property int requestedHeight: root.asideVoiceIsland ? (Aside.AsideState.hasConversation ? (Aside.AsideState.phase === "listening" ? 86 : 270) : 64) : (Aside.AsideState.hasConversation ? (Aside.AsideState.inputRequested ? 430 : 382) : (Aside.AsideState.inputRequested ? 102 : 64))
    readonly property int requestedRadius: 36 // Smooth pill shape
    
    property real currentRadius: root.isIsland ? (root.isReminderIsland ? 26 : (root.isAsideIsland ? root.requestedRadius : 18)) : Theme.radiusPanel

    implicitWidth: root.requestedWidth
    implicitHeight: root.requestedHeight

    Behavior on currentRadius { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

    Connections {
        target: Aside.AsideState
        function onInputRequestedChanged() {
            if (Aside.AsideState.inputRequested)
                asideInputFocusTimer.restart()
        }
    }

    onIsAsideIslandChanged: {
        if (root.isAsideIsland && Aside.AsideState.inputRequested)
            asideInputFocusTimer.restart()
    }

    Timer {
        id: asideInputFocusTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.isAsideIsland && Aside.AsideState.inputRequested) {
                asideInput.forceActiveFocus()
                asideInput.cursorPosition = asideInput.text.length
            }
        }
    }

    // Liquid Glass Background
    Rectangle {
        id: liquidGlassBase
        anchors.fill: parent
        visible: root.isAsideIsland
        radius: root.currentRadius
        color: Qt.rgba(0.02, 0.02, 0.02, 0.65) // Dark base for contrast
        
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 80
            blur: 1.0
            saturation: 1.15
            
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.8)
            shadowBlur: 1.0
            shadowVerticalOffset: 16
        }
        
        // Liquid glass top rim light
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.currentRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.currentRadius * 1.5
                radius: root.currentRadius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.18) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Aside.AsideState.closeIsland()
        enabled: root.isIsland
    }

    ColumnLayout {
        id: islandContent
        anchors.fill: parent
        anchors.topMargin: root.asideVoiceIsland ? 24 : 36
        anchors.bottomMargin: 24
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 16

        opacity: root.isIsland ? 1.0 : 0.0
        scale: root.isIsland ? 1.0 : 0.8
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

        // Header Row (Voice Visualizer Only)
        RowLayout {
            visible: root.asideVoiceIsland
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 36 : 0
            spacing: 0

            Item { Layout.fillWidth: true } // Left spacer

            Aside.AsideParticleVisualizer {
                Layout.preferredWidth: 320
                Layout.preferredHeight: 36
                level: Aside.AsideState.phase === "listening" ? Math.max(Aside.AsideState.audioLevel, 0.08) : (Aside.AsideState.isBusy ? 0.18 : 0.0)
                active: root.asideVoiceIsland
                opacity: root.asideVoiceIsland ? 1.0 : 0.0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Aside.AsideState.cancel()
                }
            }

            Item { Layout.fillWidth: true } // Right spacer
        }

        // Reminder Preview (Floating Style)
        ColumnLayout {
            visible: Aside.AsideState.reminderPreviewVisible
            Layout.fillWidth: true
            Layout.preferredHeight: Aside.AsideState.reminderPreviewVisible ? implicitHeight : 0
            spacing: 12
            opacity: Aside.AsideState.reminderPreviewVisible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                AppText {
                    Layout.fillWidth: true
                    text: Aside.AsideState.reminderPreviewStatus === "confirmed" ? "Напоминание подтверждено" : Aside.AsideState.reminderPreviewStatus === "cancelled" ? "Напоминание отменено" : "Подтверди напоминание"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font { pixelSize: 15; weight: Font.Medium }
                    elide: Text.ElideRight
                }

                AppText {
                    visible: Aside.AsideState.reminderPreviewStatus !== "pending"
                    text: Aside.AsideState.reminderPreviewStatus === "confirmed" ? "готово" : "отмена"
                    color: Aside.AsideState.reminderPreviewStatus === "cancelled" ? Theme.error : Theme.success
                    font { pixelSize: 14; weight: Font.Bold }
                    elide: Text.ElideRight
                }
            }

            AppText {
                Layout.fillWidth: true
                text: Aside.AsideState.reminderPreviewTitle
                color: "#ffffff"
                font { pixelSize: 22; weight: Font.Medium }
                wrapMode: Text.WordWrap
            }

            AppText {
                Layout.fillWidth: true
                text: Aside.AsideState.reminderPreviewMeta
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 14
                elide: Text.ElideRight
            }

            RowLayout {
                visible: Aside.AsideState.reminderPreviewStatus === "pending"
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 23
                    color: yesReminderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    AppText {
                        anchors.centerIn: parent
                        text: "Да"
                        color: "#ffffff"
                        font { pixelSize: 16; weight: Font.Medium }
                    }

                    MouseArea {
                        id: yesReminderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.confirmReminder(true)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 23
                    color: noReminderMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    AppText {
                        anchors.centerIn: parent
                        text: "Нет"
                        color: noReminderMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.8)
                        font { pixelSize: 16; weight: Font.Medium }
                    }

                    MouseArea {
                        id: noReminderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.confirmReminder(false)
                    }
                }
            }
        }

        // Chat History (Floating Text Style)
        Flickable {
            id: asideMessagesFlick
            visible: Aside.AsideState.hasConversation && !Aside.AsideState.reminderPreviewVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: asideMessageStack.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
            onHeightChanged: contentY = Math.max(0, contentHeight - height)
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }

            Column {
                id: asideMessageStack
                width: asideMessagesFlick.width
                y: Math.max(0, asideMessagesFlick.height - implicitHeight)
                spacing: 24 // Larger spacing between floating text blocks

                Repeater {
                    model: Aside.AsideState.messagesModel

                    delegate: Item {
                        readonly property bool shouldDisplay: index >= Math.max(0, Aside.AsideState.messagesModel.count - 2)
                        readonly property bool hiddenForReminderPreview: Aside.AsideState.reminderPreviewVisible && model.role === "assistant" && model.text === ""
                        readonly property bool shouldShow: shouldDisplay && !hiddenForReminderPreview

                        visible: shouldShow
                        width: asideMessageStack.width
                        height: shouldShow ? messageText.implicitHeight : 0
                        opacity: shouldDisplay ? (model.role === "user" ? 0.6 : 1.0) : 0
                        clip: true
                        
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        TextEdit {
                            id: messageText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: model.text === "" && model.role === "assistant" && Aside.AsideState.isBusy ? "Thinking..." : (model.text === "" && model.role === "user" && Aside.AsideState.phase === "listening" ? "Listening..." : model.text)
                            color: "#ffffff"
                            font.family: Theme.fontPrimary
                            font.pixelSize: model.role === "user" ? 18 : 22 // Siri style: large clean text
                            font.weight: model.role === "user" ? Font.Normal : Font.Medium
                            wrapMode: TextEdit.WrapAnywhere
                            readOnly: true
                            selectByMouse: true
                            clip: false
                            selectedTextColor: "#000000"
                            selectionColor: Theme.info
                        }
                    }
                }
            }
        }

        // Seamless Input Field
        RowLayout {
            visible: Aside.AsideState.inputRequested
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 42 : 0
            Layout.maximumHeight: visible ? 42 : 0
            spacing: 12
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            TextInput {
                id: asideInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                color: "#ffffff"
                font.family: Theme.fontPrimary
                font.pixelSize: 18 // Large and legible
                enabled: Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                selectByMouse: true
                clip: true
                Keys.onEscapePressed: Aside.AsideState.closeIsland()
                Keys.onReturnPressed: submitQuery()
                Keys.onEnterPressed: submitQuery()

                function submitQuery() {
                    let value = asideInput.text.trim()
                    if (value !== "") {
                        asideInput.text = ""
                        Aside.AsideState.sendQuery(value)
                    }
                }

                AppText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: Aside.AsideState.daemonAvailable ? "Ask Aside..." : "aside daemon is offline"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font: asideInput.font
                    enabled: false
                    visible: !asideInput.text && !asideInput.preeditText
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: asideSendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                opacity: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy ? 1.0 : 0.0

                AppIcon {
                    anchors.centerIn: parent
                    text: "󰒊" // send icon
                    font.pixelSize: 18
                    color: "#ffffff"
                }

                MouseArea {
                    id: asideSendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: asideInput.submitQuery()
                }
            }
        }
    }
}
