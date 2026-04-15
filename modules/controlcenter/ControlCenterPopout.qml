import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../components"
import "../../core"

PopoutWrapper {
    id: root

    popoutWidth: 320

    signal requestMathDetails()
    signal mathSessionChanged()

    // ─── Состояние страниц ──────────────────────────────────────────────
    property string currentPage: "grid" // "grid" | "wifi" | "bluetooth" | "math"

    // Числовой индекс для вычисления направления анимации
    function pageIndex(name) {
        switch (name) {
            case "grid": return 0;
            case "wifi": return 1;
            case "bluetooth": return 2;
            case "math": return 3;
            default: return 0;
        }
    }
    property int currentIndex: pageIndex(currentPage)

    // ─── Внешние данные (прокидываются из модуля) ────────────────────────
    property bool wifiConnected: false
    property string wifiEssid: ""
    property string btStatus: "off"
    property bool nightLightActive: false

    // Сброс страницы при закрытии
    onIsOpenChanged: {
        if (!isOpen) currentPage = "grid";
    }

    // Пульсация пузыря при смене страницы
    SequentialAnimation {
        id: bubbleAnim
        NumberAnimation { target: root; property: "bubbleScale"; to: 1.015; duration: 200; easing.type: Easing.InQuad}
        NumberAnimation { target: root; property: "bubbleScale"; to: 1.0; duration: 1000; easing.type: Easing.OutElastic; easing.period: 0.4; easing.amplitude: 0.9 }
    }

    onCurrentPageChanged: {
        if (isOpen) bubbleAnim.restart();
        if (currentPage === "wifi") wifiCCPoller.running = true;
        if (currentPage === "bluetooth") btCCPoller.running = true;
    }

    // =====================================================================
    //  КОНТЕЙНЕР СТРАНИЦ — все страницы лежат друг на друге, анимируются
    // =====================================================================
    Item {
        id: pageContainer
        Layout.fillWidth: true

        // Высота контейнера плавно переходит к высоте текущей страницы
        implicitHeight: {
            switch (root.currentPage) {
                case "wifi": return wifiPage.implicitHeight;
                case "bluetooth": return btPage.implicitHeight;
                case "math": return mathPage.implicitHeight;
                default: return gridContent.implicitHeight;
            }
        }
        Behavior on implicitHeight {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
        }

        clip: true

        // ─────────────────────────────────────────────────────────────────
        //  СТРАНИЦА 0: Сетка плиток
        // ─────────────────────────────────────────────────────────────────
        Item {
            id: gridPage
            width: parent.width
            implicitHeight: gridContent.implicitHeight

            property real targetOpacity: root.currentIndex === 0 ? 1.0 : 0.0
            property real targetBlur: root.currentIndex === 0 ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: gridPage.targetBlur
            }

            ColumnLayout {
                id: gridContent
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    QuickButton {
                        icon: root.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
                        label: "Wi-Fi"
                        isActive: root.wifiConnected
                        onClicked: NetworkState.toggleWifi()
                        onRightClicked: root.currentPage = "wifi"
                    }

                    QuickButton {
                        icon: root.btStatus === "off" ? "\udb80\udcb2" : "\udb80\udcaf"
                        label: "Bluetooth"
                        isActive: root.btStatus === "on" || root.btStatus === "connected"
                        onClicked: NetworkState.toggleBluetooth()
                        onRightClicked: root.currentPage = "bluetooth"
                    }

                    QuickButton {
                        icon: root.nightLightActive ? "\udb80\udd5f" : "\udb80\udd5e"
                        label: "Night Light"
                        isActive: root.nightLightActive
                        onClicked: {
                            Hyprland.dispatch("exec pkill hyprsunset || hyprsunset -t 3500")
                            root.nightLightActive = !root.nightLightActive
                        }
                    }

                    QuickButton {
                        icon: MathState.isActive ? "\uf00c" : "\udb81\udc6a"
                        label: "Math"
                        isActive: MathState.isActive
                        onClicked: root.currentPage = "math"
                    }

                    QuickButton {
                        icon: "\uf185" // Sun icon
                        label: "Display"
                        onClicked: {
                            IslandState.trigger("screenshot")
                        } 
                    }

                    QuickButton {
                        icon: "\udb80\udc03"
                        label: "Settings"
                        onClicked: {
                            root.closeRequested()
                            Hyprland.dispatch("exec env XDG_CURRENT_DESKTOP=GNOME gnome-control-center")
                        }
                    }

                    QuickButton {
                        icon: ""
                        label: "Media"
                        onClicked: {
                            root.closeRequested()
                            Hyprland.dispatch("exec xdg-open ~/Pictures")
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────
        //  СТРАНИЦА 3: Math Mode
        // ─────────────────────────────────────────────────────────────────
        Item {
            id: mathPageItem
            width: parent.width
            implicitHeight: mathPage.implicitHeight

            property real targetOpacity: root.currentIndex === 3 ? 1.0 : 0.0
            property real targetBlur: root.currentIndex === 3 ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: mathPageItem.targetBlur
            }

            ColumnLayout {
                id: mathPage
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                // Кнопка назад + заголовок
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: backMathMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: "#ffffff"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: backMathMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = "grid"
                        }
                    }

                    Text {
                        text: "Math Session"
                        color: "#ffffff"
                        font { pixelSize: 16; bold: true }
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                AppText {
                    text: MathState.isActive ? "Session is currently active." : "Starting a session will enable focus mode:"
                    color: Theme.textSecondary
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    spacing: 6
                    visible: !MathState.isActive
                    
                    RowLayout {
                        spacing: 8
                        Text { text: "•"; color: "#55ff55"; font.bold: true }
                        Text { text: "Block YouTube & distractions"; color: "#e0e0e0"; font.pixelSize: 12 }
                    }
                    RowLayout {
                        spacing: 8
                        Text { text: "•"; color: "#55ff55"; font.bold: true }
                        Text { text: "Enable MATH submap (Hyprland)"; color: "#e0e0e0"; font.pixelSize: 12 }
                    }
                    RowLayout {
                        spacing: 8
                        Text { text: "•"; color: "#55ff55"; font.bold: true }
                        Text { text: "Start focus music (MPV)"; color: "#e0e0e0"; font.pixelSize: 12 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 20
                    color: mathPageBtnMouse.containsMouse ? (MathState.isActive ? Qt.rgba(1, 0, 0, 0.15) : Qt.rgba(0, 1, 0, 0.15)) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: mathPageBtnMouse.containsMouse ? (MathState.isActive ? Qt.rgba(1, 0, 0, 0.3) : Qt.rgba(0, 1, 0, 0.3)) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    AppText {
                        anchors.centerIn: parent
                        text: MathState.isActive ? "Посмотреть статистику о текущей сессии" : "Start New Session"
                        color: mathPageBtnMouse.containsMouse ? (MathState.isActive ? Theme.info : Theme.success) : Theme.textPrimary
                        font { pixelSize: MathState.isActive ? 11 : 14; bold: true }
                    }

                    MouseArea {
                        id: mathPageBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (MathState.isActive) {
                                root.requestMathDetails();
                                root.closeRequested();
                            } else {
                                MathState.startSession()
                                root.currentPage = "grid"
                            }
                        }
                    }
                }
                
                Item { Layout.preferredHeight: 4 }
            }
        }

        // ─────────────────────────────────────────────────────────────────
        //  СТРАНИЦА 1: Wi-Fi
        // ─────────────────────────────────────────────────────────────────
        Item {
            id: wifiPageItem
            width: parent.width
            implicitHeight: wifiPage.implicitHeight

            property real targetOpacity: root.currentIndex === 1 ? 1.0 : 0.0
            property real targetBlur: root.currentIndex === 1 ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: wifiPageItem.targetBlur
            }

            ColumnLayout {
                id: wifiPage
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                // Кнопка назад + заголовок
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: backWifiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: "#ffffff"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: backWifiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = "grid"
                        }
                    }

                    Text {
                        text: "Wi-Fi"
                        color: "#ffffff"
                        font { pixelSize: 16; bold: true }
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // Статус текущего подключения
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Text {
                        text: root.wifiConnected ? "\udb82\udd28" : "\udb82\udd2b"
                        color: root.wifiConnected ? "#ffffff" : "#717171"
                        font { pixelSize: 20; bold: true }
                    }

                    Text {
                        text: root.wifiConnected ? "Connected to " + root.wifiEssid : "Disconnected"
                        color: "#e0e0e0"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: root.wifiConnected
                        implicitWidth: 70
                        implicitHeight: 26
                        radius: 13
                        color: wifiDisconnMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: wifiDisconnMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.3) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            color: wifiDisconnMouse.containsMouse ? "#ff5555" : "#aaaaaa"
                            font.pixelSize: 11
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: wifiDisconnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiPendingId = root.wifiEssid
                                Hyprland.dispatch("exec nmcli connection down id \"" + root.wifiEssid + "\"")
                            }
                        }
                    }
                }

                // Список доступных сетей
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: availNetCol.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: wifiAvailModel.count > 0

                    ColumnLayout {
                        id: availNetCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "Available Networks"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }

                        Repeater {
                            model: wifiAvailModel

                            Rectangle {
                                id: wifiNetRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: wifiNetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true

                                required property var modelData
                                property bool isPending: wifiPendingId === modelData.ssid

                                Behavior on color { ColorAnimation { duration: 150 } }

                                // Шиммер
                                Rectangle {
                                    opacity: wifiNetRect.isPending ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 600 } }
                                    width: parent.width * 0.4
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: wifiNetRect.isPending
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -wifiNetRect.width * 0.4; to: wifiNetRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    Text {
                                        text: "\udb82\udd28"
                                        color: wifiNetRect.isPending ? "#ffffff" : "#888888"
                                        font.pixelSize: 14
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text {
                                        text: modelData.ssid || ""
                                        color: wifiNetRect.isPending ? "#ffffff" : "#a0a0a0"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text {
                                        text: (modelData.signal || "0") + "%"
                                        color: "#555555"
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    id: wifiNetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiPendingId = modelData.ssid
                                        Hyprland.dispatch("exec nmcli device wifi connect \"" + modelData.ssid + "\"")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────
        //  СТРАНИЦА 2: Bluetooth
        // ─────────────────────────────────────────────────────────────────
        Item {
            id: btPageItem
            width: parent.width
            implicitHeight: btPage.implicitHeight

            property real targetOpacity: root.currentIndex === 2 ? 1.0 : 0.0
            property real targetBlur: root.currentIndex === 2 ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: btPageItem.targetBlur
            }

            ColumnLayout {
                id: btPage
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                // Кнопка назад + заголовок
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: backBtMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            color: "#ffffff"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: backBtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = "grid"
                        }
                    }

                    Text {
                        text: "Bluetooth"
                        color: "#ffffff"
                        font { pixelSize: 16; bold: true }
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // Статус BT
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Text {
                        text: root.btStatus === "off" ? "\udb80\udcb2" : "\udb80\udcaf"
                        color: root.btStatus !== "off" ? "#ffffff" : "#717171"
                        font { pixelSize: 20; bold: true }
                    }

                    Text {
                        text: {
                            switch (root.btStatus) {
                                case "connected": return "Connected";
                                case "on": return "No connection";
                                default: return "Bluetooth Off";
                            }
                        }
                        color: "#e0e0e0"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                }

                // Подключённые устройства
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: btConnCol.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: btConnectedModel.count > 0

                    ColumnLayout {
                        id: btConnCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "Connected"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }

                        Repeater {
                            model: btConnectedModel

                            Rectangle {
                                id: btConnRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: btConnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true

                                required property var modelData
                                property bool isPending: btPendingMac === modelData.mac

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    opacity: btConnRect.isPending ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 600 } }
                                    width: parent.width * 0.4
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: btConnRect.isPending
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -btConnRect.width * 0.4; to: btConnRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    Text { text: "\udb80\udcaf"; color: "#ffffff"; font.pixelSize: 14 }
                                    Text {
                                        text: modelData.name || ""
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: btConnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        btPendingMac = modelData.mac
                                        Hyprland.dispatch("exec bluetoothctl disconnect " + modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }

                // Сопряжённые устройства
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: btPairedCol.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    visible: btPairedModel.count > 0

                    ColumnLayout {
                        id: btPairedCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6

                        Text {
                            text: "Paired Devices"
                            color: "#888888"
                            font { pixelSize: 11; bold: true }
                        }

                        Repeater {
                            model: btPairedModel

                            Rectangle {
                                id: btPairedRect
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 6
                                color: btPairedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                clip: true

                                required property var modelData
                                property bool isPending: btPendingMac === modelData.mac

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    opacity: btPairedRect.isPending ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 600 } }
                                    width: parent.width * 0.4
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.15) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: btPairedRect.isPending
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -btPairedRect.width * 0.4; to: btPairedRect.width; duration: 1200; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 300 }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    Text {
                                        text: "\udb80\udcaf"
                                        color: btPairedRect.isPending ? "#ffffff" : "#888888"
                                        font.pixelSize: 14
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text {
                                        text: modelData.name || ""
                                        color: btPairedRect.isPending ? "#ffffff" : "#a0a0a0"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }

                                MouseArea {
                                    id: btPairedMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        btPendingMac = modelData.mac
                                        Hyprland.dispatch("exec bluetoothctl connect " + modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }

                // Кнопка менеджера
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: btSettingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Open Bluetooth Manager"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: btSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hyprland.dispatch("exec blueman-manager")
                            root.closeRequested()
                        }
                    }
                }
            }
        }
    }

    // =====================================================================
    //  POLLING: Wi-Fi
    // =====================================================================
    property string wifiPendingId: ""
    ListModel { id: wifiAvailModel }

    Process {
        id: wifiCCPoller
        command: ["sh", "-c", "nmcli -t -f active,ssid,signal dev wifi"]

        stdout: SplitParser {
            property var tempAvail: []
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
                            if (activeStr !== "yes" && tempAvail.length < 8) {
                                tempAvail.push({ ssid: ssid, signal: signal });
                            }
                        }
                    }
                }
            }
        }

        onExited: {
            const parser = stdout as SplitParser;
            wifiAvailModel.clear();
            for (let item of parser.tempAvail) wifiAvailModel.append(item);
            parser.tempAvail = [];
            parser.seenSsid = [];
            wifiPendingId = "";
        }
    }

    Timer {
        interval: 3000
        running: root.isOpen && root.currentPage === "wifi"
        repeat: true
        onTriggered: wifiCCPoller.running = true
    }


    // =====================================================================
    //  POLLING: Bluetooth
    // =====================================================================
    property string btPendingMac: ""
    ListModel { id: btConnectedModel }
    ListModel { id: btPairedModel }

    Process {
        id: btCCPoller
        command: ["sh", "-c", "echo '==CONNECTED=='; bluetoothctl devices Connected; echo '==PAIRED=='; bluetoothctl devices Paired"]

        stdout: SplitParser {
            property string currentMode: "none"
            property var tempConnected: []
            property var tempPaired: []

            onRead: data => {
                let line = data.trim();
                if (line === "==CONNECTED==") { currentMode = "connected"; tempConnected = []; return; }
                if (line === "==PAIRED==") { currentMode = "paired"; tempPaired = []; return; }
                if (line.length > 0 && line.startsWith("Device")) {
                    let parts = line.split(" ");
                    if (parts.length >= 3) {
                        let mac = parts[1];
                        let name = parts.slice(2).join(" ");
                        if (currentMode === "connected") {
                            tempConnected.push({ mac: mac, name: name });
                        } else if (currentMode === "paired") {
                            if (!tempConnected.some(d => d.mac === mac)) {
                                tempPaired.push({ mac: mac, name: name });
                            }
                        }
                    }
                }
            }
        }

        onExited: {
            const parser = stdout as SplitParser;
            btConnectedModel.clear();
            for (let item of parser.tempConnected) btConnectedModel.append(item);
            btPairedModel.clear();
            for (let item of parser.tempPaired) btPairedModel.append(item);
            btPendingMac = "";
        }
    }

    Timer {
        interval: 3000
        running: root.isOpen && root.currentPage === "bluetooth"
        repeat: true
        onTriggered: btCCPoller.running = true
    }

    // =====================================================================
    //  POLLING: Night Light + Math Mode processes
    // =====================================================================
    Timer {
        id: mathConfirmTimer
        interval: 3000
        onTriggered: root.mathConfirming = false
    }

    Process {
        id: nightLightPoller
        command: ["sh", "-c", "pgrep -x hyprsunset > /dev/null && echo on || echo off"]
        stdout: SplitParser {
            onRead: data => { root.nightLightActive = data.trim() === "on"; }
        }
    }



    Timer {
        interval: 2000
        running: root.isOpen && root.currentPage === "grid"
        repeat: true
        onTriggered: {
            nightLightPoller.running = true;
        }
    }

    Component.onCompleted: {
        nightLightPoller.running = true;
    }
}
