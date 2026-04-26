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

    popoutWidth: 660

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
            case "localsend": return 4;
            default: return 0;
        }
    }

    function formatMathSessionDate(value) {
        if (!value)
            return "—";

        let parts = String(value).split("-");
        if (parts.length === 3)
            return parts[2] + "." + parts[1];

        return String(value);
    }

    function mathSessionMaxChars() {
        let sessions = MathState.recentSessions || [];
        let maxValue = 0;

        for (let i = 0; i < sessions.length; ++i) {
            let session = sessions[i] || {};
            let chars = Number(session.chars !== undefined ? session.chars : 0);
            maxValue = Math.max(maxValue, chars);
        }

        return Math.max(1, maxValue);
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
        if (currentPage === "math") MathState.refresh();
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
                case "localsend": return lsPage.implicitHeight;
                default: return gridPage.implicitHeight;
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
            implicitHeight: mainGridLayout.implicitHeight
            height: implicitHeight

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

            RowLayout {
                id: mainGridLayout
                anchors.fill: parent
                spacing: 16

                ColumnLayout {
                    id: gridContent
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
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
                            icon: "\uf185"
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

                        QuickButton {
                            icon: "\uf1d8"
                            label: "LocalSend"
                            onClicked: root.currentPage = "localsend"
                        }
                    }
                }

                Rectangle {
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    id: notificationColumn
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    property real panelHeight: Math.max(160, gridContent.implicitHeight - notificationsHeader.implicitHeight - spacing)

                    RowLayout {
                        id: notificationsHeader
                        Layout.fillWidth: true
                        spacing: 8

                        AppText {
                            text: "Notifications"
                            color: "#ffffff"
                            font { pixelSize: 14; bold: true }
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: notificationList.count > 0
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: clearAllMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            AppIcon {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: "#ffffff"
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: clearAllMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationState.clearAll()
                            }
                        }
                    }

                    Item {
                        visible: notificationList.count === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: notificationColumn.panelHeight

                        Text {
                            text: "No new notifications"
                            color: "#666666"
                            font.pixelSize: 13
                            anchors.centerIn: parent
                        }
                    }

                    ListView {
                        id: notificationList
                        visible: count > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: notificationColumn.panelHeight
                        clip: true
                        spacing: 8
                        model: NotificationState.activeNotifications

                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad }
                            NumberAnimation { property: "x"; from: notificationList.width * 0.3; to: 0; duration: 400; easing.type: Easing.OutQuint }
                        }

                        remove: Transition {
                            NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { property: "x"; to: -notificationList.width * 0.2; duration: 250; easing.type: Easing.InQuad }
                        }

                        displaced: Transition {
                            NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutQuad }
                            NumberAnimation { property: "opacity"; to: 1; duration: 200 }
                        }

                        delegate: Rectangle {
                            width: ListView.view ? ListView.view.width : 320
                            height: notificationLayout.implicitHeight + 16
                            radius: 12
                            color: Qt.rgba(1, 1, 1, notificationMouse.containsMouse ? 0.12 : 0.06)
                            border.color: notificationMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            border.width: 1

                            property var notificationData: modelData

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: notificationMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (notificationData) {
                                        notificationData.invokeDefaultAction();
                                        notificationData.dismiss();
                                    }
                                }
                            }

                            ColumnLayout {
                                id: notificationLayout
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    AppText {
                                        text: notificationData && notificationData.appName ? notificationData.appName : "System"
                                        color: Theme.textSecondary
                                        font { pixelSize: 12; weight: Font.DemiBold }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 10
                                        color: dismissMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                        z: 1

                                        AppText {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 11
                                            color: Theme.textSecondary
                                        }

                                        MouseArea {
                                            id: dismissMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (notificationData) {
                                                    notificationData.dismiss();
                                                }
                                            }
                                        }
                                    }
                                }

                                AppText {
                                    Layout.fillWidth: true
                                    text: notificationData && notificationData.summary ? notificationData.summary : "Notification"
                                    color: Theme.textPrimary
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font { pixelSize: 14; weight: Font.DemiBold }
                                }

                                AppText {
                                    Layout.fillWidth: true
                                    text: notificationData && notificationData.body ? notificationData.body : ""
                                    visible: text !== ""
                                    color: Theme.textSecondary
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                }
                            }
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

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            AppText {
                                text: "Completed Sessions"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            AppText {
                                text: MathState.sessionsCompleted
                                color: Theme.textPrimary
                                font { pixelSize: 22; bold: true }
                            }

                            AppText {
                                text: MathState.lastSessionDate ? "Last: " + root.formatMathSessionDate(MathState.lastSessionDate) : "No history yet"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            AppText {
                                text: "Total Symbols"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            AppText {
                                text: MathState.totalChars
                                color: Theme.textPrimary
                                font { pixelSize: 22; bold: true }
                            }

                            AppText {
                                text: "Lifetime progress"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            AppText {
                                text: "Total Formulas"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            AppText {
                                text: MathState.totalFormulas
                                color: Theme.textPrimary
                                font { pixelSize: 22; bold: true }
                            }

                            AppText {
                                text: "Detected in notes"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            AppText {
                                text: "Average / Session"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            AppText {
                                text: MathState.averageCharsPerSession
                                color: Theme.textPrimary
                                font { pixelSize: 22; bold: true }
                            }

                            AppText {
                                text: MathState.streakDays > 0 ? MathState.streakDays + " day streak" : "No streak yet"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    implicitHeight: mathStatsPanel.implicitHeight + 28

                    ColumnLayout {
                        id: mathStatsPanel
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            AppText {
                                text: "Recent Sessions"
                                color: Theme.textPrimary
                                font { pixelSize: 14; bold: true }
                                Layout.fillWidth: true
                            }

                            AppText {
                                text: MathState.recentSessions.length > 0 ? MathState.recentSessions.length + " tracked" : "Waiting for data"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: MathState.lastSessionDate ? "Last session: " + root.formatMathSessionDate(MathState.lastSessionDate) : "Complete one session to unlock the chart."
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }

                        Item {
                            visible: MathState.recentSessions.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 156

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Repeater {
                                    model: MathState.recentSessions

                                    delegate: Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        property var sessionData: modelData
                                        property real sessionChars: Number(sessionData && sessionData.chars !== undefined ? sessionData.chars : 0)
                                        property int sessionFormulas: Number(sessionData && sessionData.formulas !== undefined ? sessionData.formulas : 0)
                                        property bool isLatest: index === MathState.recentSessions.length - 1

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 6

                                            AppText {
                                                Layout.fillWidth: true
                                                text: Math.round(sessionChars)
                                                color: isLatest ? Theme.textPrimary : Theme.textSecondary
                                                font.pixelSize: 10
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: Math.min(28, Math.max(16, parent.width * 0.45))
                                                    height: sessionChars > 0 ? Math.max(12, (sessionChars / root.mathSessionMaxChars()) * (parent.height - 4)) : 6
                                                    radius: width / 2
                                                    color: isLatest ? Theme.info : Qt.rgba(1, 1, 1, 0.18)
                                                    opacity: sessionChars > 0 ? 1.0 : 0.45
                                                }
                                            }

                                            AppText {
                                                Layout.fillWidth: true
                                                text: root.formatMathSessionDate(sessionData && sessionData.date ? sessionData.date : "")
                                                color: Theme.textSecondary
                                                font.pixelSize: 10
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            AppText {
                                                Layout.fillWidth: true
                                                text: sessionFormulas > 0 ? sessionFormulas + " f" : ""
                                                color: Theme.textSecondary
                                                font.pixelSize: 10
                                                horizontalAlignment: Text.AlignHCenter
                                                visible: text !== ""
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            visible: MathState.recentSessions.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96

                            AppText {
                                anchors.centerIn: parent
                                text: "No completed sessions yet"
                                color: Theme.textSecondary
                                font.pixelSize: 12
                            }
                        }
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

        // ─────────────────────────────────────────────────────────────────
        //  СТРАНИЦА 4: LocalSend
        // ─────────────────────────────────────────────────────────────────
        Item {
            id: lsPageItem
            width: parent.width
            implicitHeight: lsPage.implicitHeight

            property real targetOpacity: root.currentIndex === 4 ? 1.0 : 0.0
            property real targetBlur: root.currentIndex === 4 ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: lsPageItem.targetBlur
            }

            LocalSendPage {
                id: lsPage
                anchors.left: parent.left
                anchors.right: parent.right
                onBackRequested: root.currentPage = "grid"
            }
        }
    }
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
