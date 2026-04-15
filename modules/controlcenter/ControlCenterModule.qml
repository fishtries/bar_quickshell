import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Effects
import "../../core"

Rectangle {
    id: root
    color: Theme.bgPanel
    radius: Theme.radiusPanel

    implicitWidth: iconsRow.width + 12
    implicitHeight: iconsRow.height + 4

    property bool popoutOpen: false
    property Item popoutItem: popout

    // ─── Данные Wi-Fi ───────────────────────────────────────────────────
    property bool wifiConnected: NetworkState.wifiConnected
    property string wifiEssid: NetworkState.wifiEssid

    property string pendingEssid: NetworkState.pendingEssid
    property bool pendingConnected: NetworkState.pendingConnected

    // ─── Данные Bluetooth ───────────────────────────────────────────────
    property string displayBtStatus: NetworkState.btStatus
    property string pendingBtStatus: NetworkState.pendingBtStatus

    Binding {
        target: root
        property: "displayBtStatus"
        value: NetworkState.btStatus
        when: !btCrossfade.running
    }

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
                NetworkState.wifiEssid = NetworkState.pendingEssid;
                NetworkState.wifiConnected = NetworkState.pendingConnected;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }
    
    Connections {
        target: NetworkState
        function onWifiUpdateTriggered() {
            wifiCrossfade.restart()
        }
        function onBtUpdateTriggered() {
            btCrossfade.restart()
        }
    }

    // ─── Crossfade: Bluetooth ───────────────────────────────────────────
    SequentialAnimation {
        id: btCrossfade
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction { 
            script: {
                root.displayBtStatus = NetworkState.pendingBtStatus;
                NetworkState.btStatus = NetworkState.pendingBtStatus;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: 200 }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
        }
    }



    // ─── Двойная иконка в баре ──────────────────────────────────────────
    Row {
        id: iconsRow
        anchors.centerIn: parent
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
                    switch (root.displayBtStatus) {
                        case "connected": return "\udb80\udcaf";
                        case "on":        return "\udb80\udcaf" + "?";
                        default:          return "\udb80\udcb2";
                    }
                }
                color: (root.displayBtStatus === "on" || root.displayBtStatus === "connected") ? Theme.textDark : Theme.textSecondary
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
                color: root.wifiConnected ? Theme.textDark : Theme.textSecondary
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

    ControlCenterPopout {
        id: popout
        isOpen: root.popoutOpen

        wifiConnected: NetworkState.wifiConnected
        wifiEssid: NetworkState.wifiEssid
        btStatus: root.displayBtStatus

        onCloseRequested: root.popoutOpen = false
        onRequestMathDetails: MathState.popoutOpen = true

        anchors.top: iconsRow.bottom
        anchors.topMargin: 6
        anchors.right: iconsRow.right

        // Анимация открывается из центра между иконками Wi-Fi и Bluetooth
        originX: popout.popoutWidth - (iconsRow.width / 2)
    }
}
