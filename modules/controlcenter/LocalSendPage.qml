import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../core"
import "../../components"

ColumnLayout {
    id: root

    signal backRequested()

    spacing: 10

    property bool scanning: LocalSendState.devices.length === 0 && scanSpinner.running

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
                        onClicked: LocalSendState.sendClipboard(deviceRect.deviceIp)
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
                            implicitWidth: 60
                            implicitHeight: 24
                            radius: 12
                            color: sendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Send"
                                color: sendMouse.containsMouse ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LocalSendState.sendClipboard(deviceRect.deviceIp)
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
