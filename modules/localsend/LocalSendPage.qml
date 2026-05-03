import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "."
import "../../core"
import "../../components"

ColumnLayout {
    id: root

    signal backRequested()

    spacing: 10

    property bool scanning: LocalSendState.devices.length === 0 && scanSpinner.running
    readonly property bool transferBusy: LocalSendState.currentTransfer.active === true
    property string manualIp: "192.168.1.112"

    // Кнопка назад + заголовок + кнопка сканирования
    RowLayout {
        spacing: 8
        Layout.fillWidth: true

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "←"
                color: "#ffffff"
                font.pixelSize: 16
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            text: "LocalSend"
            color: "#ffffff"
            font { pixelSize: 16; bold: true }
            Layout.fillWidth: true
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: receiveMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (LocalSendState.receiverRunning ? Qt.rgba(0.35, 1, 0.55, 0.12) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "↓"
                color: LocalSendState.receiverRunning ? "#67ff8d" : (receiveMouse.containsMouse ? "#ffffff" : "#aaaaaa")
                font.pixelSize: 16
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: receiveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LocalSendState.startReceiver()
            }
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: scanMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: scanIcon
                anchors.centerIn: parent
                text: "⟳"
                color: scanMouse.containsMouse ? "#ffffff" : "#aaaaaa"
                font.pixelSize: 16
                Behavior on color { ColorAnimation { duration: 150 } }

                RotationAnimation on rotation {
                    id: scanSpinner
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000
                    running: false
                }
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !scanSpinner.running
                onClicked: {
                    if (scanSpinner.running)
                        return
                    LocalSendState.devices = []
                    scanSpinner.running = true
                    LocalSendState.scan()
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: manualRow.implicitHeight + 16
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.03)

        RowLayout {
            id: manualRow
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            TextInput {
                id: manualIpInput
                Layout.fillWidth: true
                text: root.manualIp
                color: "#ffffff"
                selectionColor: Qt.rgba(1, 1, 1, 0.2)
                selectedTextColor: "#ffffff"
                font.pixelSize: 12
                clip: true
                onTextChanged: root.manualIp = text

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: manualIpInput.text.length === 0
                    text: "Manual IP"
                    color: "#666666"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                implicitWidth: 62
                implicitHeight: 26
                radius: 13
                color: manualSendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                opacity: root.transferBusy || root.manualIp.trim().length === 0 ? 0.55 : 1.0
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: root.transferBusy ? "Busy" : "Send"
                    color: manualSendMouse.containsMouse ? "#ffffff" : "#aaaaaa"
                    font.pixelSize: 11
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: manualSendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.transferBusy && root.manualIp.trim().length > 0
                    onClicked: LocalSendState.pickAndSend({
                        "name": root.manualIp.trim(),
                        "alias": root.manualIp.trim(),
                        "ip": root.manualIp.trim(),
                        "port": 53317,
                        "protocol": "auto",
                        "version": "auto",
                        "os": "manual"
                    })
                }
            }
        }
    }

    Connections {
        target: LocalSendState
        function onScanFinished() {
            scanSpinner.running = false
        }
    }

    // Пустое состояние
    Item {
        visible: LocalSendState.devices.length === 0 && !scanSpinner.running
        Layout.fillWidth: true
        implicitHeight: 80

        Text {
            anchors.centerIn: parent
            text: "No devices found"
            color: "#666666"
            font.pixelSize: 13
        }
    }

    // Сканирование — индикатор
    Item {
        visible: LocalSendState.devices.length === 0 && scanSpinner.running
        Layout.fillWidth: true
        implicitHeight: 80

        Text {
            anchors.centerIn: parent
            text: "Scanning…"
            color: "#888888"
            font.pixelSize: 13
        }
    }

    // Список устройств
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: deviceListCol.implicitHeight + 16
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.03)
        visible: LocalSendState.devices.length > 0

        ColumnLayout {
            id: deviceListCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            Text {
                text: "Nearby Devices"
                color: "#888888"
                font { pixelSize: 11; bold: true }
            }

            Repeater {
                model: LocalSendState.devices

                Rectangle {
                    id: deviceRect
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: deviceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    required property var modelData
                    property string deviceName: modelData.name || "Unknown"
                    property string deviceIp: modelData.ip || ""
                    property string deviceOs: modelData.os || "unknown"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.transferBusy
                        onClicked: LocalSendState.pickAndSend(deviceRect.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "📱"
                            font.pixelSize: 16
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: deviceRect.deviceName
                                color: "#ffffff"
                                font { pixelSize: 13; weight: Font.DemiBold }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: deviceRect.deviceIp + " · " + deviceRect.deviceOs
                                color: "#888888"
                                font.pixelSize: 10
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 24
                            radius: 12
                            color: sendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            opacity: root.transferBusy ? 0.55 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.transferBusy ? "Busy" : "Files"
                                color: sendMouse.containsMouse ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.transferBusy
                                onClicked: LocalSendState.pickAndSend(deviceRect.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        scanSpinner.running = true
        LocalSendState.scan()
    }
}
