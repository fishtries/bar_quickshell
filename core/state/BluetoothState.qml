pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ─── Public State ────────────────────────────────────────────────
    property string btStatus: "off"
    property string pendingBtStatus: "off"

    // Pending device operation tracking (connect/disconnect shimmer)
    property string pendingMac: ""

    // Popout open state (controls device list polling cadence)
    property bool popoutOpen: false

    // Device lists
    property alias connectedDevices: connectedModel
    property alias pairedDevices: pairedModel

    // ─── Signals ─────────────────────────────────────────────────────
    signal btUpdateTriggered()

    // ─── Public Functions ────────────────────────────────────────────

    function commitBtUpdate() {
        root.btStatus = root.pendingBtStatus;
    }

    function togglePower() {
        btToggleProc.running = true;
    }

    function connectDevice(mac) {
        root.pendingMac = mac;
        connectProc.command = ["bluetoothctl", "connect", mac];
        connectProc.running = true;
    }

    function disconnectDevice(mac) {
        root.pendingMac = mac;
        disconnectProc.command = ["bluetoothctl", "disconnect", mac];
        disconnectProc.running = true;
    }

    function refreshDeviceList() {
        devicePoller.running = true;
    }

    function refreshBtStatus() {
        btStatusPoller.running = true;
    }

    function openManager() {
        managerProc.running = true;
    }

    // ─── Internal ────────────────────────────────────────────────────

    ListModel { id: connectedModel }
    ListModel { id: pairedModel }

    Process {
        id: btToggleProc
        command: ["rfkill", "toggle", "bluetooth"]
        onExited: btStatusPoller.running = true
    }

    Process {
        id: connectProc
        command: []
        onExited: {
            root.pendingMac = "";
            btStatusPoller.running = true;
            devicePoller.running = true;
        }
    }

    Process {
        id: disconnectProc
        command: []
        onExited: {
            root.pendingMac = "";
            btStatusPoller.running = true;
            devicePoller.running = true;
        }
    }

    Process {
        id: managerProc
        command: ["blueman-manager"]
    }

    Process {
        id: btStatusPoller
        command: ["sh", "-c", "if rfkill list bluetooth | grep -q 'Soft blocked: yes'; then echo 'off'; elif [ -n \"$(bluetoothctl devices Connected)\" ]; then echo 'connected'; else echo 'on'; fi"]

        stdout: SplitParser {
            onRead: data => {
                let res = data.trim();
                if ((res === "off" || res === "on" || res === "connected") && res !== root.btStatus) {
                    root.pendingBtStatus = res;
                    root.btUpdateTriggered();
                }
            }
        }
    }

    Process {
        id: devicePoller
        command: ["sh", "-c", "echo '==CONNECTED=='; bluetoothctl devices Connected; echo '==PAIRED=='; bluetoothctl devices Paired"]

        stdout: SplitParser {
            property string currentMode: "none"
            property var tempConnected: []
            property var tempPaired: []

            onRead: data => {
                let line = data.trim();
                if (line === "==CONNECTED==") {
                    currentMode = "connected";
                    tempConnected = [];
                    return;
                }
                if (line === "==PAIRED==") {
                    currentMode = "paired";
                    tempPaired = [];
                    return;
                }

                if (line.length > 0 && line.startsWith("Device")) {
                    let parts = line.split(" ");
                    if (parts.length >= 3) {
                        let mac = parts[1];
                        let name = parts.slice(2).join(" ");

                        if (currentMode === "connected") {
                            tempConnected.push({ mac: mac, name: name });
                        } else if (currentMode === "paired") {
                            let isConnected = tempConnected.some(d => d.mac === mac);
                            if (!isConnected) {
                                tempPaired.push({ mac: mac, name: name });
                            }
                        }
                    }
                }
            }
        }

        onExited: {
            const parser = stdout as SplitParser;

            connectedModel.clear();
            for (let item of parser.tempConnected) connectedModel.append(item);

            pairedModel.clear();
            for (let item of parser.tempPaired) pairedModel.append(item);

            parser.tempConnected = [];
            parser.tempPaired = [];

            root.pendingMac = "";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: btStatusPoller.running = true
    }

    Timer {
        interval: 3000
        running: root.popoutOpen
        repeat: true
        onTriggered: devicePoller.running = true
    }

    onPopoutOpenChanged: {
        if (popoutOpen) devicePoller.running = true;
    }

    Component.onCompleted: {
        btStatusPoller.running = true;
    }
}
