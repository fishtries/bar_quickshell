pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ─── Public State ────────────────────────────────────────────────
    property bool wifiConnected: false
    property string wifiEssid: ""
    property int signalStrength: 0

    // Crossfade coordination (set by poller, consumed by UI animations)
    property string pendingEssid: ""
    property bool pendingConnected: false

    // Pending network operation tracking (connect/disconnect shimmer)
    property string pendingId: ""

    // Popout open state (controls network list polling cadence)
    property bool popoutOpen: false

    // Network lists
    property alias currentConnections: currentConnModel
    property alias availableNetworks: availWfModel

    // ─── Signals ─────────────────────────────────────────────────────
    signal wifiUpdateTriggered()

    // ─── Public Functions ────────────────────────────────────────────

    function commitWifiUpdate() {
        root.wifiEssid = root.pendingEssid;
        root.wifiConnected = root.pendingConnected;
    }

    function toggleWifi() {
        wifiToggleProc.running = true
    }

    function connectToNetwork(ssid) {
        root.pendingId = ssid;
        connectProc.command = ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    function disconnectFromNetwork(ssid) {
        root.pendingId = ssid;
        disconnectProc.command = ["nmcli", "connection", "down", "id", ssid];
        disconnectProc.running = true;
    }

    function refreshNetworkList() {
        networkListPoller.running = true;
    }

    function refreshWifiStatus() {
        wifiStatusPoller.running = true;
    }

    // ─── Internal ────────────────────────────────────────────────────

    function processWifiData(data) {
        let line = data.trim();
        if (line.length > 0) {
            let parts = line.split(":");
            if (parts.length >= 3) {
                wifiStatusPoller.found = true;
                let newSsid = parts[1];
                let newSignal = parseInt(parts[2]) || 0;
                if (!root.wifiConnected || newSsid !== root.wifiEssid) {
                    root.pendingConnected = true;
                    root.pendingEssid = newSsid;
                    root.signalStrength = newSignal;
                    root.wifiUpdateTriggered();
                } else {
                    root.signalStrength = newSignal;
                }
            }
        }
    }

    ListModel { id: currentConnModel }
    ListModel { id: availWfModel }

    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", "toggle"]
        onExited: wifiStatusPoller.running = true
    }

    Process {
        id: connectProc
        command: []
        onExited: {
            root.pendingId = "";
            wifiStatusPoller.running = true;
            networkListPoller.running = true;
        }
    }

    Process {
        id: disconnectProc
        command: []
        onExited: {
            root.pendingId = "";
            wifiStatusPoller.running = true;
            networkListPoller.running = true;
        }
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
                root.signalStrength = 0;
                root.wifiUpdateTriggered();
            }
            found = false;
        }
    }

    Process {
        id: networkListPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi"]

        stdout: SplitParser {
            property var tempCurrWifi: []
            property var tempAvailWifi: []
            property var seenSsid: []

            onRead: data => {
                let line = data.trim();
                if (line.length === 0) return;

                let firstColon = line.indexOf(':');
                if (firstColon !== -1) {
                    let activeStr = line.substring(0, firstColon);
                    let rest = line.substring(firstColon + 1);
                    let lastColon = rest.lastIndexOf(':');
                    if (lastColon !== -1) {
                        let ssid = rest.substring(0, lastColon);
                        let signal = rest.substring(lastColon + 1);

                        if (ssid.length > 0 && ssid !== "--" && !seenSsid.includes(ssid)) {
                            seenSsid.push(ssid);
                            if (activeStr === "yes") {
                                tempCurrWifi.push({ ssid: ssid, signal: signal });
                            } else {
                                if (tempAvailWifi.length < 8) {
                                    tempAvailWifi.push({ ssid: ssid, signal: signal });
                                }
                            }
                        }
                    }
                }
            }
        }

        onExited: {
            const parser = stdout as SplitParser;

            currentConnModel.clear();
            for (let item of parser.tempCurrWifi) currentConnModel.append(item);

            availWfModel.clear();
            for (let item of parser.tempAvailWifi) availWfModel.append(item);

            parser.tempCurrWifi = [];
            parser.tempAvailWifi = [];
            parser.seenSsid = [];

            root.pendingId = "";
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            wifiStatusPoller.running = true;
        }
    }

    Timer {
        interval: 3000
        running: root.popoutOpen
        repeat: true
        onTriggered: networkListPoller.running = true
    }

    onPopoutOpenChanged: {
        if (popoutOpen) networkListPoller.running = true;
    }

    Component.onCompleted: {
        wifiStatusPoller.running = true;
    }
}
