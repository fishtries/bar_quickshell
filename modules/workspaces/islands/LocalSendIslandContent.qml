import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../components"
import "../../../core"
import "../../localsend" as LocalSend

Item {
    id: root

    property var currentTransfer: IslandState.transferData
    property bool isLocalSendConfirming: root.currentTransfer && root.currentTransfer.status === "confirming"
    property bool isDropHint: IslandState.isLocalSendDrop
    property bool isPicker: IslandState.isLocalSendPicker
    property var pendingFiles: IslandState.pendingSendFiles || []
    property var devices: LocalSend.LocalSendState.devices || []
    property real islandContentOpacity: 1.0

    readonly property int pickerRowHeight: 56
    readonly property int pickerHeaderHeight: 64
    readonly property int pickerMaxRows: 4
    readonly property int pickerListHeight: Math.max(pickerRowHeight, Math.min(pickerMaxRows, Math.max(1, root.devices.length)) * pickerRowHeight)

    readonly property int requestedWidth: root.isDropHint ? 380 : (root.isPicker ? 560 : (root.isLocalSendConfirming ? 680 : 560))
    readonly property int requestedHeight: root.isDropHint ? 64 : (root.isPicker ? (pickerHeaderHeight + pickerListHeight + 16) : 80)
    readonly property int requestedRadius: root.isPicker ? 22 : 18

    onIsPickerChanged: {
        if (root.isPicker)
            LocalSend.LocalSendState.scan()
    }

    function shortName(path) {
        if (typeof path !== "string" || path.length === 0)
            return ""
        let trimmed = path
        if (trimmed.indexOf("file://") === 0)
            trimmed = decodeURIComponent(trimmed.substring(7))
        let idx = trimmed.lastIndexOf("/")
        return idx >= 0 ? trimmed.substring(idx + 1) : trimmed
    }

    function pickerSubtitle() {
        let count = root.pendingFiles.length
        if (count === 0)
            return ""
        if (count === 1)
            return root.shortName(root.pendingFiles[0])
        return root.shortName(root.pendingFiles[0]) + " and " + (count - 1) + " more"
    }

    function sendToDevice(device) {
        if (!device || root.pendingFiles.length === 0)
            return
        let files = root.pendingFiles.slice()
        IslandState.pendingSendFiles = []
        LocalSend.LocalSendState.sendFiles(device, files)
    }

    function clampTransferProgress() {
        let transfer = root.currentTransfer
        if (!transfer)
            return 0

        return Math.max(0, Math.min(1, Number(transfer.progress || 0)))
    }

    function formatTransferBytes(value) {
        let bytes = Number(value || 0)
        if (bytes < 1024)
            return `${Math.round(bytes)} B`
        if (bytes < 1024 * 1024)
            return `${(bytes / 1024).toFixed(1)} KB`
        if (bytes < 1024 * 1024 * 1024)
            return `${(bytes / 1024 / 1024).toFixed(1)} MB`
        return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
    }

    function transferTitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return "LocalSend"

        if (transfer.status === "finished")
            return transfer.direction === "receive" ? "Received" : "Sent"
        if (transfer.status === "error")
            return "LocalSend failed"
        if (transfer.status === "preparing")
            return "Preparing transfer"

        return transfer.direction === "receive" ? "Receiving" : "Sending"
    }

    function transferSubtitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return ""

        if (transfer.status === "error")
            return transfer.message || "Transfer failed"

        let peer = transfer.peer || "Device"
        let file = transfer.fileName ? ` · ${transfer.fileName}` : ""
        let bytes = transfer.totalBytes > 0 ? ` · ${root.formatTransferBytes(transfer.sentBytes)} / ${root.formatTransferBytes(transfer.totalBytes)}` : ""
        return `${peer}${file}${bytes}`
    }

    function incomingConfirmationSubtitle() {
        let transfer = root.currentTransfer
        if (!transfer)
            return ""

        let count = Number(transfer.fileCount || 0)
        let files = count === 1 ? "1 file" : `${count} files`
        let bytes = transfer.totalBytes > 0 ? ` · ${root.formatTransferBytes(transfer.totalBytes)}` : ""
        return `${transfer.peer || "Device"} wants to send ${files}${bytes}`
    }

    RowLayout {
        id: islandContent
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        opacity: IslandState.isActive ? 1.0 : 0.0
        scale: IslandState.isActive ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
        layer.enabled: IslandState.isActive
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 28
            blur: 0.0
        }

        // Transfer progress UI
        RowLayout {
            visible: !root.isLocalSendConfirming && !root.isDropHint && !root.isPicker
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppIcon {
                text: root.currentTransfer && root.currentTransfer.status === "error" ? "\uf071" : "\uf0ec"
                font.pixelSize: 20
                color: root.currentTransfer && root.currentTransfer.status === "error" ? Theme.error : Theme.info
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    AppText {
                        text: root.transferTitle()
                        color: "#ffffff"
                        font { pixelSize: 14; weight: Font.Bold }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    AppText {
                        text: `${Math.round(root.clampTransferProgress() * 100)}%`
                        color: "#cccccc"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * root.clampTransferProgress()
                        radius: 3
                        color: root.currentTransfer && root.currentTransfer.status === "error" ? Theme.error : Theme.info
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    }
                }

                AppText {
                    text: root.transferSubtitle()
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
        }

        // Incoming confirmation UI
        RowLayout {
            visible: root.isLocalSendConfirming
            opacity: root.islandContentOpacity
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AppIcon {
                text: "\uf019"
                font.pixelSize: 20
                color: Theme.info
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                AppText {
                    text: "Accept incoming files?"
                    color: "#ffffff"
                    font { pixelSize: 14; weight: Font.Bold }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                AppText {
                    text: root.incomingConfirmationSubtitle()
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 34
                radius: 17
                color: rejectReceiveMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.22) : Qt.rgba(1, 0.3, 0.3, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 0.3, 0.3, rejectReceiveMouse.containsMouse ? 0.4 : 0.2)

                AppText {
                    anchors.centerIn: parent
                    text: "Reject"
                    color: "#ffffff"
                    font { pixelSize: 12; weight: Font.DemiBold }
                }

                MouseArea {
                    id: rejectReceiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.LocalSendState.confirmReceive(false)
                }
            }

            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 34
                radius: 17
                color: acceptReceiveMouse.containsMouse ? Qt.rgba(0.4, 1, 0.55, 0.22) : Qt.rgba(0.4, 1, 0.55, 0.12)
                border.width: 1
                border.color: Qt.rgba(0.4, 1, 0.55, acceptReceiveMouse.containsMouse ? 0.4 : 0.2)

                AppText {
                    anchors.centerIn: parent
                    text: "Accept"
                    color: "#ffffff"
                    font { pixelSize: 12; weight: Font.DemiBold }
                }

                MouseArea {
                    id: acceptReceiveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.LocalSendState.confirmReceive(true)
                }
            }
        }
    }

    // ─── Drop hint UI ───────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 12
        visible: root.isDropHint
        opacity: root.isDropHint ? 1.0 : 0.0
        scale: root.isDropHint ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

        AppText {
            text: "Wanna LocalSend?"
            color: "#aaaaaa"
            font.pixelSize: 11
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    // ─── Peer picker UI ─────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 8
        visible: root.isPicker
        opacity: root.isPicker ? 1.0 : 0.0
        scale: root.isPicker ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.22)
                border.width: 1
                border.color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.55)

                AppIcon {
                    anchors.centerIn: parent
                    text: "\uf1d8"
                    font.pixelSize: 16
                    color: Theme.info
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                AppText {
                    text: "Send to..."
                    color: "#ffffff"
                    font { pixelSize: 14; weight: Font.Bold }
                }
                AppText {
                    text: root.pickerSubtitle()
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                id: pickerCancelButton
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: pickerCancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 150 } }

                AppIcon {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.pixelSize: 12
                    color: "#ffffff"
                }

                MouseArea {
                    id: pickerCancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandState.hide()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.pickerListHeight
            color: "transparent"

            ListView {
                id: peersList
                anchors.fill: parent
                clip: true
                spacing: 4
                interactive: contentHeight > height
                model: root.devices

                delegate: Rectangle {
                    width: peersList.width
                    height: root.pickerRowHeight - 4
                    radius: 12
                    color: peerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.20)

                            AppIcon {
                                anchors.centerIn: parent
                                text: {
                                    let dt = (modelData.deviceType || modelData.os || "").toLowerCase()
                                    if (dt.indexOf("mobile") >= 0 || dt.indexOf("android") >= 0 || dt.indexOf("ios") >= 0)
                                        return "\uf3cd"
                                    if (dt.indexOf("server") >= 0 || dt.indexOf("headless") >= 0)
                                        return "\uf233"
                                    return "\uf109"
                                }
                                font.pixelSize: 14
                                color: Theme.info
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            AppText {
                                text: modelData.alias || modelData.name || modelData.ip || "Device"
                                color: "#ffffff"
                                font { pixelSize: 13; weight: Font.DemiBold }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            AppText {
                                text: (modelData.ip || "") + (modelData.deviceModel ? " · " + modelData.deviceModel : "")
                                color: "#9a9a9a"
                                font.pixelSize: 10
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        AppIcon {
                            text: "\uf061"
                            font.pixelSize: 12
                            color: peerMouse.containsMouse ? Theme.info : "#888888"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: peerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sendToDevice(modelData)
                    }
                }
            }

            // Empty / scanning placeholder
            Item {
                anchors.fill: parent
                visible: root.devices.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    AppIcon {
                        text: "\uf002"
                        font.pixelSize: 18
                        color: "#666666"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    AppText {
                        text: LocalSend.LocalSendState.devices.length === 0 ? "Searching for devices..." : ""
                        color: "#888888"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

}
