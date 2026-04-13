import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: root

    implicitWidth: iconsRow.width
    implicitHeight: iconsRow.height

    property bool popoutOpen: false
    property Item popoutItem: popout

    // ─── Данные Wi-Fi ───────────────────────────────────────────────────
    property bool wifiConnected: false
    property string wifiEssid: ""

    // Приватные для crossfade
    property string pendingEssid: ""
    property bool pendingConnected: false

    // ─── Данные Bluetooth ───────────────────────────────────────────────
    property string btStatus: "off"
    property string pendingBtStatus: "off"

    // ─── Данные Math Mode ───────────────────────────────────────────
    property bool mathActive: false

    // ─── Crossfade: Wi-Fi ───────────────────────────────────────────────
    SequentialAnimation {
        id: wifiCrossfade
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                root.wifiEssid = root.pendingEssid;
                root.wifiConnected = root.pendingConnected;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }

    // ─── Crossfade: Bluetooth ───────────────────────────────────────────
    SequentialAnimation {
        id: btCrossfade
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { script: root.btStatus = root.pendingBtStatus }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }

    // ─── Polling Wi-Fi ──────────────────────────────────────────────────
    Process {
        id: wifiStatusPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -n 1"]
        property bool found: false

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (line.length > 0) {
                    let parts = line.split(":");
                    if (parts.length >= 3) {
                        wifiStatusPoller.found = true;
                        let newSsid = parts[1];
                        if (!root.wifiConnected || newSsid !== root.wifiEssid) {
                            root.pendingConnected = true;
                            root.pendingEssid = newSsid;
                            wifiCrossfade.restart();
                        }
                    }
                }
            }
        }

        onExited: {
            if (!found && root.wifiConnected) {
                root.pendingConnected = false;
                root.pendingEssid = "";
                wifiCrossfade.restart();
            }
            found = false;
        }
    }

    // ─── Polling Bluetooth ──────────────────────────────────────────────
    Process {
        id: btStatusPoller
        command: ["sh", "-c", "if rfkill list bluetooth | grep -q 'Soft blocked: yes'; then echo 'off'; elif [ -n \"$(bluetoothctl devices Connected)\" ]; then echo 'connected'; else echo 'on'; fi"]

        stdout: SplitParser {
            onRead: data => {
                let res = data.trim();
                if ((res === "off" || res === "on" || res === "connected") && res !== root.btStatus) {
                    root.pendingBtStatus = res;
                    btCrossfade.restart();
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            wifiStatusPoller.running = true;
            btStatusPoller.running = true;
        }
    }

    Component.onCompleted: {
        wifiStatusPoller.running = true;
        btStatusPoller.running = true;
    }

    // ─── Двойная иконка в баре ──────────────────────────────────────────
    Row {
        id: iconsRow
        spacing: 0

        // Bluetooth icon
        Rectangle {
            id: btRect
            width: 44
            height: 36
            radius: 18
            color: "transparent"

            Text {
                id: btIcon
                anchors.centerIn: parent
                property real blurValue: 0.0

                text: {
                    switch (root.btStatus) {
                        case "connected": return "\udb80\udcaf";
                        case "on":        return "\udb80\udcaf";
                        default:          return "\udb80\udcb2";
                    }
                }
                color: (root.btStatus === "on" || root.btStatus === "connected") ? "#000000" : "#555555"
                font { pixelSize: 18; bold: true }
                Behavior on color { ColorAnimation { duration: 300 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: btIcon.blurValue
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popoutOpen = !root.popoutOpen
                onPressed: btRect.opacity = 0.7
                onReleased: btRect.opacity = 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }

        // Wi-Fi icon
        Rectangle {
            id: wifiRect
            width: 44
            height: 36
            radius: 18
            color: "transparent"

            Text {
                id: wifiIcon
                anchors.centerIn: parent
                property real blurValue: 0.0

                text: root.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
                color: root.wifiConnected ? "#000000" : "#555555"
                font { pixelSize: 18; bold: true }
                Behavior on color { ColorAnimation { duration: 300 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: wifiIcon.blurValue
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.popoutOpen = !root.popoutOpen
                onPressed: wifiRect.opacity = 0.7
                onReleased: wifiRect.opacity = 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }

    // ─── Попаут ─────────────────────────────────────────────────────────
    signal requestMathDetails()
    signal mathSessionChanged()

    ControlCenterPopout {
        id: popout
        isOpen: root.popoutOpen
        
        onRequestMathDetails: root.requestMathDetails()
        onMathSessionChanged: root.mathSessionChanged()

        wifiConnected: root.wifiConnected
        wifiEssid: root.wifiEssid
        btStatus: root.btStatus
        mathActive: root.mathActive

        onCloseRequested: root.popoutOpen = false

        anchors.top: iconsRow.bottom
        anchors.topMargin: 6
        anchors.right: iconsRow.right

        // Анимация открывается из центра между иконками Wi-Fi и Bluetooth
        originX: popout.popoutWidth - (iconsRow.width / 2)
    }
}
