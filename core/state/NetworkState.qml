pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool wifiConnected: false
    property string wifiEssid: ""
    
    // Properties to allow crossfade coordination outside:
    property string pendingEssid: ""
    property bool pendingConnected: false

    property string btStatus: "off"
    property string pendingBtStatus: "off"

    function processWifiData(data) {
        let line = data.trim();
        if (line.length > 0) {
            let parts = line.split(":");
            if (parts.length >= 3) {
                wifiStatusPoller.found = true;
                let newSsid = parts[1];
                if (!root.wifiConnected || newSsid !== root.wifiEssid) {
                    root.pendingConnected = true;
                    root.pendingEssid = newSsid;
                    wifiUpdateTriggered();
                }
            }
        }
    }

    signal wifiUpdateTriggered()
    signal btUpdateTriggered()

    function toggleWifi() {
        wifiToggleProc.running = true
    }

    function toggleBluetooth() {
        btToggleProc.running = true
    }

    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", "toggle"]
        onExited: wifiStatusPoller.running = true
    }

    Process {
        id: btToggleProc
        command: ["rfkill", "toggle", "bluetooth"]
        onExited: btStatusPoller.running = true
    }

    Process {
        id: wifiStatusPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -n 1"]
        property bool found: false

        stdout: SplitParser {
            onRead: data => root.processWifiData(data)
        }

        onExited: {
            if (!found && root.wifiConnected) {
                root.pendingConnected = false;
                root.pendingEssid = "";
                root.wifiUpdateTriggered();
            }
            found = false;
        }
    }

    Process {
        id: btStatusPoller
        command: ["sh", "-c", "if rfkill list bluetooth | grep -q 'Soft blocked: yes'; then echo 'off'; elif [ -n \"$(bluetoothctl devices Connected)\" ]; then echo 'connected'; else echo 'on'; fi"]

        stdout: SplitParser {
            onRead: data => {
                let res = data.trim();
                // Check against btStatus to avoid constant re-triggering
                if ((res === "off" || res === "on" || res === "connected") && res !== root.btStatus) {
                    root.pendingBtStatus = res;
                    root.btUpdateTriggered();
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
}
