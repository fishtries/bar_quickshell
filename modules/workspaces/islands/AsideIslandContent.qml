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
    readonly property bool asideDecoratedIsland: root.isAsideIsland
    readonly property real asideVoiceLevel: Math.max(0, Math.min(1, Aside.AsideState.audioLevel))
    readonly property real asideGlowEnergy: root.asideDecoratedIsland ? Math.max(root.asideVoiceIsland ? root.asideVoiceLevel : 0, root.asideVoiceIsland ? (Aside.AsideState.phase === "listening" ? 0.08 : (Aside.AsideState.isBusy ? 0.14 : 0.04)) : (Aside.AsideState.isBusy ? 0.11 : (Aside.AsideState.inputRequested ? 0.055 : 0.035))) : 0
    readonly property real asideVoiceTrackThickness: root.asideDecoratedIsland ? (root.asideVoiceIsland ? 6 + root.asideGlowEnergy * 2.0 : 4 + root.asideGlowEnergy * 1.2) : 0
    readonly property real asideVoiceTrailLength: root.asideDecoratedIsland ? (root.asideVoiceIsland ? 0.18 + root.asideGlowEnergy * 0.05 : 0.13 + root.asideGlowEnergy * 0.035) : 0
    readonly property int requestedWidth: root.asideVoiceIsland ? 540 : 760
    readonly property int requestedHeight: root.asideVoiceIsland ? (Aside.AsideState.hasConversation ? (Aside.AsideState.phase === "listening" ? 92 : 270) : 54) : (Aside.AsideState.hasConversation ? (Aside.AsideState.inputRequested ? 430 : 382) : (Aside.AsideState.inputRequested ? 146 : 96))
    readonly property int requestedRadius: 28
    property real currentRadius: root.isIsland ? (root.isReminderIsland ? 26 : (root.isAsideIsland ? root.requestedRadius : 18)) : Theme.radiusPanel
    property real asideGlowProgress: 0.0

    implicitWidth: root.requestedWidth
    implicitHeight: root.requestedHeight

    Behavior on currentRadius { NumberAnimation { duration: 400 } }

    function asideBorderX(progress, margin) {
        let w = Math.max(1, root.width - margin * 2)
        let h = Math.max(1, root.height - margin * 2)
        let d = ((progress % 1 + 1) % 1) * 2 * (w + h)
        if (d < w)
            return margin + d
        if (d < w + h)
            return root.width - margin
        if (d < 2 * w + h)
            return root.width - margin - (d - w - h)
        return margin
    }

    function asideBorderY(progress, margin) {
        let w = Math.max(1, root.width - margin * 2)
        let h = Math.max(1, root.height - margin * 2)
        let d = ((progress % 1 + 1) % 1) * 2 * (w + h)
        if (d < w)
            return margin
        if (d < w + h)
            return margin + (d - w)
        if (d < 2 * w + h)
            return root.height - margin
        return root.height - margin - (d - 2 * w - h)
    }

    function asideBorderHorizontal(progress) {
        let margin = 9
        let w = Math.max(1, root.width - margin * 2)
        let h = Math.max(1, root.height - margin * 2)
        let d = ((progress % 1 + 1) % 1) * 2 * (w + h)
        return d < w || (d >= w + h && d < 2 * w + h)
    }

    function asideRoundedBorderPoint(progress, margin) {
        let r = Math.max(1, Math.min(root.currentRadius, root.width / 2 - margin, root.height / 2 - margin))
        let x0 = margin
        let y0 = margin
        let x1 = root.width - margin
        let y1 = root.height - margin
        let straightW = Math.max(1, x1 - x0 - 2 * r)
        let straightH = Math.max(1, y1 - y0 - 2 * r)
        let arc = Math.PI * r / 2
        let total = 2 * (straightW + straightH) + 4 * arc
        let d = ((progress % 1 + 1) % 1) * total

        if (d < straightW)
            return Qt.point(x0 + r + d, y0)
        d -= straightW
        if (d < arc) {
            let a = -Math.PI / 2 + d / r
            return Qt.point(x1 - r + Math.cos(a) * r, y0 + r + Math.sin(a) * r)
        }
        d -= arc
        if (d < straightH)
            return Qt.point(x1, y0 + r + d)
        d -= straightH
        if (d < arc) {
            let a = d / r
            return Qt.point(x1 - r + Math.cos(a) * r, y1 - r + Math.sin(a) * r)
        }
        d -= arc
        if (d < straightW)
            return Qt.point(x1 - r - d, y1)
        d -= straightW
        if (d < arc) {
            let a = Math.PI / 2 + d / r
            return Qt.point(x0 + r + Math.cos(a) * r, y1 - r + Math.sin(a) * r)
        }
        d -= arc
        if (d < straightH)
            return Qt.point(x0, y1 - r - d)
        d -= straightH
        let a = Math.PI + d / r
        return Qt.point(x0 + r + Math.cos(a) * r, y0 + r + Math.sin(a) * r)
    }

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

    Timer {
        interval: 16
        repeat: true
        running: root.asideDecoratedIsland
        onTriggered: root.asideGlowProgress = (root.asideGlowProgress + 0.0012 + root.asideGlowEnergy * 0.0006) % 1.0
    }

    Rectangle {
        anchors.fill: parent
        visible: root.asideDecoratedIsland
        radius: root.currentRadius
        color: "transparent"
        border.width: root.asideVoiceIsland ? 3 : 2
        border.color: Qt.rgba(1, 1, 1, root.asideVoiceIsland ? 0.95 : 0.82)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        visible: root.asideDecoratedIsland
        opacity: root.asideDecoratedIsland ? (root.asideVoiceIsland ? 1 : 0.72) : 0
        radius: root.currentRadius + 4
        color: "transparent"
        border.width: root.asideVoiceIsland ? 4 : 3
        border.color: Qt.rgba(1, 1, 1, root.asideVoiceIsland ? 0.65 + root.asideGlowEnergy * 0.35 : 0.46 + root.asideGlowEnergy * 0.24)
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 48
            blur: (root.asideVoiceIsland ? 0.5 : 0.36) + root.asideGlowEnergy * 0.25
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Canvas {
        id: asideVoiceTrailCanvas
        anchors.fill: parent
        visible: root.asideDecoratedIsland
        opacity: root.asideDecoratedIsland ? (root.asideVoiceIsland ? 1 : 0.78) : 0
        onPaint: {
            let ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!root.asideDecoratedIsland)
                return

            let steps = 140
            let margin = 1
            let head = root.asideGlowProgress
            let tail = root.asideGlowProgress - root.asideVoiceTrailLength
            let tailPoint = root.asideRoundedBorderPoint(tail, margin)
            let headPoint = root.asideRoundedBorderPoint(head, margin)
            let gradient = ctx.createLinearGradient(tailPoint.x, tailPoint.y, headPoint.x, headPoint.y)
            gradient.addColorStop(0.0, "rgba(255,255,255,0.00)")
            gradient.addColorStop(0.42, root.asideVoiceIsland ? "rgba(255,255,255,0.88)" : "rgba(255,255,255,0.56)")
            gradient.addColorStop(1.0, root.asideVoiceIsland ? "rgba(255,255,255,1.00)" : "rgba(255,255,255,0.82)")
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = root.asideVoiceTrackThickness
            ctx.strokeStyle = gradient

            ctx.beginPath()
            for (let i = 0; i <= steps; ++i) {
                let point = root.asideRoundedBorderPoint(tail + root.asideVoiceTrailLength * (i / steps), margin)
                if (i === 0)
                    ctx.moveTo(point.x, point.y)
                else
                    ctx.lineTo(point.x, point.y)
            }
            ctx.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onAsideGlowProgressChanged() { asideVoiceTrailCanvas.requestPaint() }
            function onAsideVoiceTrackThicknessChanged() { asideVoiceTrailCanvas.requestPaint() }
            function onAsideVoiceTrailLengthChanged() { asideVoiceTrailCanvas.requestPaint() }
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    RowLayout {
        id: islandContent
        anchors.fill: parent
        anchors.leftMargin: root.asideVoiceIsland ? 24 : 16
        anchors.rightMargin: root.asideVoiceIsland ? 24 : 16
        anchors.topMargin: root.asideVoiceIsland ? 22 : 16
        anchors.bottomMargin: root.asideVoiceIsland ? 22 : 16
        spacing: 12

        opacity: root.isIsland ? 1.0 : 0.0
        scale: root.isIsland ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
        layer.enabled: root.isIsland
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 28
            blur: 0.0
        }

        ColumnLayout {
            visible: root.isAsideIsland
            opacity: 1.0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.asideVoiceIsland ? 14 : 10

            RowLayout {
                visible: !root.asideVoiceIsland
                Layout.fillWidth: true
                Layout.preferredHeight: root.asideVoiceIsland ? 48 : 42
                spacing: 12

                Rectangle {
                    visible: !root.asideVoiceIsland
                    Layout.preferredWidth: root.asideVoiceIsland ? 48 : 42
                    Layout.preferredHeight: root.asideVoiceIsland ? 48 : 42
                    radius: root.asideVoiceIsland ? 20 : 16
                    color: Qt.rgba(1, 1, 1, root.asideVoiceIsland ? 0.08 : 0.075)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, root.asideVoiceIsland ? 0.16 : 0.12)

                    AppIcon {
                        anchors.centerIn: parent
                        text: Aside.AsideState.phase === "listening" ? "󰍬" : "󰚩"
                        font.pixelSize: root.asideVoiceIsland ? 22 : 20
                        color: "#ffffff"
                    }

                    layer.enabled: false
                    layer.effect: MultiEffect {
                        shadowEnabled: false
                        shadowColor: "transparent"
                        shadowBlur: 0
                        shadowScale: 1
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                ColumnLayout {
                    visible: !root.asideVoiceIsland
                    Layout.preferredWidth: root.asideVoiceIsland ? 260 : 190
                    Layout.fillWidth: root.asideVoiceIsland
                    spacing: 2

                    AppText {
                        Layout.fillWidth: true
                        text: root.asideVoiceIsland ? (Aside.AsideState.phase === "listening" ? "Говори, я слушаю" : "Aside отвечает") : "Aside"
                        color: "#ffffff"
                        font { pixelSize: root.asideVoiceIsland ? 18 : 15; weight: Font.Bold }
                        elide: Text.ElideRight
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: root.asideVoiceIsland ? (Aside.AsideState.phase === "listening" ? "Распознанный текст появится внутри" : "Ответ появится ниже и будет озвучен") : Aside.AsideState.shortModelName + " · " + Aside.AsideState.statusText
                        color: Aside.AsideState.errorMessage !== "" ? Theme.warning : "#aaaaaa"
                        font.pixelSize: root.asideVoiceIsland ? 12 : 11
                        elide: Text.ElideRight
                    }
                }

                Aside.AsideParticleVisualizer {
                    visible: !root.asideVoiceIsland
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.asideVoiceIsland ? 0 : 42
                    level: Aside.AsideState.phase === "listening" ? Math.max(Aside.AsideState.audioLevel, 0.06) : (Aside.AsideState.isBusy ? 0.18 : 0.02)
                    active: root.isAsideIsland && (Aside.AsideState.phase === "listening" || Aside.AsideState.isBusy)
                }

                Rectangle {
                    visible: !root.asideVoiceIsland
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideNewMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, asideNewMouse.containsMouse ? 0.20 : 0.10)

                    AppIcon {
                        anchors.centerIn: parent
                        text: "\uf067"
                        font.pixelSize: 13
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: asideNewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.newConversation()
                    }
                }

                Rectangle {
                    visible: !root.asideVoiceIsland
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideMicMouse.containsMouse || Aside.AsideState.phase === "listening" ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, asideMicMouse.containsMouse || Aside.AsideState.phase === "listening" ? 0.24 : 0.12)

                    AppIcon {
                        anchors.centerIn: parent
                        text: "󰍬"
                        font.pixelSize: 14
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: asideMicMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Aside.AsideState.startMic()
                    }
                }

                Rectangle {
                    visible: !root.asideVoiceIsland
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: asideCloseMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: asideCloseMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.36) : Qt.rgba(1, 1, 1, 0.10)

                    AppIcon {
                        anchors.centerIn: parent
                        text: Aside.AsideState.isBusy ? "󰓛" : "\uf00d"
                        font.pixelSize: 13
                        color: asideCloseMouse.containsMouse ? Theme.error : "#ffffff"
                    }

                    MouseArea {
                        id: asideCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Aside.AsideState.isBusy)
                                Aside.AsideState.cancel()
                            else
                                Aside.AsideState.closeIsland()
                        }
                    }
                }
            }

            Rectangle {
                visible: Aside.AsideState.reminderPreviewVisible
                Layout.fillWidth: true
                Layout.preferredHeight: Aside.AsideState.reminderPreviewVisible ? Math.max(96, reminderPreviewIslandColumn.implicitHeight + 24) : 0
                radius: root.asideVoiceIsland ? 24 : 20
                color: Qt.rgba(1, 1, 1, root.asideVoiceIsland ? 0.115 : 0.085)
                border.width: 1
                border.color: Aside.AsideState.reminderPreviewStatus === "cancelled" ? Qt.rgba(1, 0.3, 0.3, 0.42) : Aside.AsideState.reminderPreviewStatus === "confirmed" ? Qt.rgba(0.3, 1, 0.55, 0.34) : Qt.rgba(1, 1, 1, 0.22)

                ColumnLayout {
                    id: reminderPreviewIslandColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.asideVoiceIsland ? 16 : 13
                    spacing: root.asideVoiceIsland ? 8 : 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        AppIcon {
                            text: "󰔛"
                            font.pixelSize: root.asideVoiceIsland ? 18 : 15
                            color: "#ffffff"
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: Aside.AsideState.reminderPreviewStatus === "confirmed" ? "Напоминание подтверждено" : Aside.AsideState.reminderPreviewStatus === "cancelled" ? "Напоминание отменено" : "Подтверди напоминание"
                            color: "#ffffff"
                            font { pixelSize: root.asideVoiceIsland ? 16 : 13; weight: Font.Bold }
                            elide: Text.ElideRight
                        }

                        AppText {
                            visible: Aside.AsideState.reminderPreviewStatus !== "pending"
                            text: Aside.AsideState.reminderPreviewStatus === "confirmed" ? "готово" : "отмена"
                            color: Aside.AsideState.reminderPreviewStatus === "cancelled" ? Theme.error : Theme.success
                            font { pixelSize: root.asideVoiceIsland ? 12 : 11; weight: Font.Bold }
                            elide: Text.ElideRight
                        }
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: Aside.AsideState.reminderPreviewTitle
                        color: "#ffffff"
                        font { pixelSize: root.asideVoiceIsland ? 18 : 15; weight: Font.Bold }
                        wrapMode: Text.WordWrap
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: Aside.AsideState.reminderPreviewMeta
                        color: "#bbbbbb"
                        font.pixelSize: root.asideVoiceIsland ? 13 : 12
                        elide: Text.ElideRight
                    }

                    AppText {
                        visible: Aside.AsideState.reminderPreviewTranscript !== ""
                        Layout.fillWidth: true
                        text: "Слушаю: " + Aside.AsideState.reminderPreviewTranscript
                        color: "#bbbbbb"
                        font.pixelSize: root.asideVoiceIsland ? 13 : 12
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        visible: Aside.AsideState.reminderPreviewStatus === "pending"
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.asideVoiceIsland ? 38 : 34
                            radius: root.asideVoiceIsland ? 18 : 15
                            color: yesReminderMouse.containsMouse ? Qt.rgba(0.3, 1, 0.55, 0.24) : Qt.rgba(0.3, 1, 0.55, 0.14)
                            border.width: 1
                            border.color: Qt.rgba(0.3, 1, 0.55, 0.36)

                            AppText {
                                anchors.centerIn: parent
                                text: "Да"
                                color: Theme.success
                                font { pixelSize: root.asideVoiceIsland ? 15 : 13; weight: Font.Bold }
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
                            Layout.preferredHeight: root.asideVoiceIsland ? 38 : 34
                            radius: root.asideVoiceIsland ? 18 : 15
                            color: noReminderMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.22) : Qt.rgba(1, 0.3, 0.3, 0.12)
                            border.width: 1
                            border.color: Qt.rgba(1, 0.3, 0.3, 0.34)

                            AppText {
                                anchors.centerIn: parent
                                text: "Нет"
                                color: Theme.error
                                font { pixelSize: root.asideVoiceIsland ? 15 : 13; weight: Font.Bold }
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
            }

            Flickable {
                id: asideMessagesFlick
                visible: Aside.AsideState.hasConversation
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
                    spacing: root.asideVoiceIsland ? 12 : 8

                    Repeater {
                        model: Aside.AsideState.messagesModel

                        delegate: Rectangle {
                            readonly property bool shouldDisplay: index >= Math.max(0, Aside.AsideState.messagesModel.count - 2)
                            readonly property bool voiceUser: root.asideVoiceIsland && model.role === "user"
                            readonly property bool voiceAssistant: root.asideVoiceIsland && model.role === "assistant"
                            readonly property bool hiddenForReminderPreview: Aside.AsideState.reminderPreviewVisible && model.role === "assistant" && model.text === ""
                            readonly property bool shouldShow: shouldDisplay && !hiddenForReminderPreview

                            visible: shouldShow
                            width: voiceUser ? Math.min(asideMessageStack.width, 620) : asideMessageStack.width
                            height: shouldShow ? Math.max(root.asideVoiceIsland ? 72 : 54, asideRoleLabel.implicitHeight + asideMessageText.implicitHeight + (root.asideVoiceIsland ? 30 : 24)) : 0
                            x: voiceUser ? (asideMessageStack.width - width) / 2 : 0
                            radius: root.asideVoiceIsland ? 24 : 20
                            color: root.asideVoiceIsland && model.role === "user" ? "transparent" : Qt.rgba(1, 1, 1, model.role === "user" ? (root.asideVoiceIsland ? 0 : 0.085) : (root.asideVoiceIsland ? 0.095 : 0.075))
                            border.width: root.asideVoiceIsland && model.role === "user" ? 0 : 1
                            border.color: root.asideVoiceIsland && model.role === "user" ? "transparent" : Qt.rgba(1, 1, 1, model.role === "user" ? 0.16 : (root.asideVoiceIsland ? 0.15 : 0.10))
                            opacity: shouldDisplay ? 1 : 0
                            scale: shouldDisplay ? 1 : 0.96
                            layer.enabled: false
                            layer.effect: MultiEffect {
                                shadowEnabled: false
                                shadowColor: "transparent"
                                shadowBlur: 0
                                shadowScale: 1
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }
                            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                            AppText {
                                id: asideRoleLabel
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: root.asideVoiceIsland ? 16 : 12
                                anchors.rightMargin: root.asideVoiceIsland ? 16 : 12
                                anchors.topMargin: root.asideVoiceIsland ? 12 : 9
                                visible: !root.asideVoiceIsland
                                text: model.role === "user" ? (root.asideVoiceIsland ? "Распознано" : "You") : (root.asideVoiceIsland ? "Ответ" : "Aside")
                                color: model.role === "user" ? "#ffffff" : "#ffffff"
                                font { pixelSize: root.asideVoiceIsland ? 12 : 11; weight: Font.Bold }
                                elide: Text.ElideRight
                            }

                            TextEdit {
                                id: asideMessageText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: root.asideVoiceIsland ? parent.top : asideRoleLabel.bottom
                                anchors.leftMargin: root.asideVoiceIsland ? 16 : 12
                                anchors.rightMargin: root.asideVoiceIsland ? 16 : 12
                                anchors.topMargin: root.asideVoiceIsland ? 16 : 4
                                text: model.text === "" && model.role === "assistant" && Aside.AsideState.isBusy ? "…" : (model.text === "" && model.role === "user" && Aside.AsideState.phase === "listening" ? "…" : model.text)
                                color: "#eeeeee"
                                font.family: Theme.fontPrimary
                                font.pixelSize: root.asideVoiceIsland ? (model.role === "user" ? 18 : 15) : 13
                                wrapMode: TextEdit.Wrap
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

            Rectangle {
                visible: Aside.AsideState.inputRequested
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 42 : 0
                radius: 21
                color: asideInput.activeFocus ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                border.color: asideInput.activeFocus ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 8

                    TextInput {
                        id: asideInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.family: Theme.fontPrimary
                        font.pixelSize: 14
                        enabled: Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                        selectByMouse: true
                        clip: true
                        Keys.onEscapePressed: Aside.AsideState.closeIsland()
                        Keys.onReturnPressed: {
                            let value = asideInput.text.trim()
                            if (value !== "") {
                                asideInput.text = ""
                                Aside.AsideState.sendQuery(value)
                            }
                        }
                        Keys.onEnterPressed: {
                            let value = asideInput.text.trim()
                            if (value !== "") {
                                asideInput.text = ""
                                Aside.AsideState.sendQuery(value)
                            }
                        }

                        AppText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Aside.AsideState.daemonAvailable ? "Ask Aside…" : "aside daemon is offline"
                            color: "#777777"
                            font: asideInput.font
                            enabled: false
                            visible: !asideInput.text && !asideInput.preeditText
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: asideSendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.10)
                        opacity: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy ? 1.0 : 0.45

                        AppIcon {
                            anchors.centerIn: parent
                            text: "󰒊"
                            font.pixelSize: 14
                            color: "#ffffff"
                        }

                        MouseArea {
                            id: asideSendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: asideInput.text.trim() !== "" && Aside.AsideState.daemonAvailable && !Aside.AsideState.isBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let value = asideInput.text.trim()
                                if (value !== "") {
                                    asideInput.text = ""
                                    Aside.AsideState.sendQuery(value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
