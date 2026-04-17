import QtQuick
import QtQuick.Effects
import "../../core"

Row {
    id: root

    property bool isNotifIsland: false
    property string displayBtStatus: NetworkState.btStatus

    signal popoutToggleRequested()

    width: implicitWidth
    height: implicitHeight

    spacing: 0
    opacity: root.isNotifIsland ? 0.0 : 1.0
    scale: root.isNotifIsland ? 0.6 : 1.0

    Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationFast } }
    Behavior on scale { NumberAnimation { duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingOvershootOut } }

    Binding {
        target: root
        property: "displayBtStatus"
        value: NetworkState.btStatus
        when: !btCrossfade.running
    }

    SequentialAnimation {
        id: wifiCrossfade
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 0.0; duration: AnimationConfig.durationFast }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 1.0; duration: AnimationConfig.durationFast; easing.type: AnimationConfig.easingDefaultIn }
        }
        ScriptAction {
            script: {
                NetworkState.wifiEssid = NetworkState.pendingEssid
                NetworkState.wifiConnected = NetworkState.pendingConnected
            }
        }
        ParallelAnimation {
            NumberAnimation { target: wifiIcon; property: "opacity"; to: 1.0; duration: AnimationConfig.durationFast }
            NumberAnimation { target: wifiIcon; property: "blurValue"; to: 0.0; duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut }
        }
    }

    SequentialAnimation {
        id: btCrossfade
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 0.0; duration: AnimationConfig.durationFast }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 1.0; duration: AnimationConfig.durationFast; easing.type: AnimationConfig.easingDefaultIn }
        }
        ScriptAction {
            script: {
                root.displayBtStatus = NetworkState.pendingBtStatus
                NetworkState.btStatus = NetworkState.pendingBtStatus
            }
        }
        ParallelAnimation {
            NumberAnimation { target: btIcon; property: "opacity"; to: 1.0; duration: AnimationConfig.durationFast }
            NumberAnimation { target: btIcon; property: "blurValue"; to: 0.0; duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingDefaultOut }
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

    Rectangle {
        id: btRect
        width: 44
        height: 36
        radius: 18
        color: "transparent"

        Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationUltraFast } }

        Text {
            id: btIcon
            anchors.centerIn: parent
            property real blurValue: 0.0

            text: {
                switch (root.displayBtStatus) {
                    case "connected": return "\udb80\udcaf"
                    case "on": return "\udb80\udcaf" + "?"
                    default: return "\udb80\udcb2"
                }
            }
            color: (root.displayBtStatus === "on" || root.displayBtStatus === "connected") ? Theme.textDark : Theme.textSecondary
            font { pixelSize: 18; bold: true }
            Behavior on color { ColorAnimation { duration: AnimationConfig.durationNormal } }

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: AnimationConfig.blurMaxLight
                blur: btIcon.blurValue
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popoutToggleRequested()
            onPressed: btRect.opacity = 0.7
            onReleased: btRect.opacity = 1.0
        }
    }

    Rectangle {
        id: wifiRect
        width: 44
        height: 36
        radius: 18
        color: "transparent"

        Behavior on opacity { NumberAnimation { duration: AnimationConfig.durationUltraFast } }

        Text {
            id: wifiIcon
            anchors.centerIn: parent
            property real blurValue: 0.0

            text: NetworkState.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
            color: NetworkState.wifiConnected ? Theme.textDark : Theme.textSecondary
            font { pixelSize: 18; bold: true }
            Behavior on color { ColorAnimation { duration: AnimationConfig.durationNormal } }

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: AnimationConfig.blurMaxLight
                blur: wifiIcon.blurValue
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.popoutToggleRequested()
            onPressed: wifiRect.opacity = 0.7
            onReleased: wifiRect.opacity = 1.0
        }
    }
}
