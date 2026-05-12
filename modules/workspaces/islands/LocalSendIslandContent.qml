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
    property real islandContentOpacity: 1.0

    readonly property int requestedWidth: root.isLocalSendConfirming ? 680 : 560
    readonly property int requestedHeight: 80
    readonly property int requestedRadius: 18

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
            visible: !root.isLocalSendConfirming
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

}
