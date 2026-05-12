import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

ColumnLayout {
    id: mathPage

    spacing: 12

    signal requestClose()
    signal requestMathDetails()
    signal requestCloseRequested()

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

    // Кнопка назад + заголовок
    RowLayout {
        spacing: 8
        Layout.fillWidth: true

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: backMathMouse.containsMouse ? Theme.bgHover : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "←"
                color: Theme.textPrimary
                font.pixelSize: 16
            }

            MouseArea {
                id: backMathMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mathPage.requestClose()
            }
        }

        Text {
            text: "Math Session"
            color: Theme.textPrimary
            font { pixelSize: 16; bold: true }
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.borderSubtle
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
            Text { text: "Block YouTube & distractions"; color: Theme.textPrimary; font.pixelSize: 12 }
        }
        RowLayout {
            spacing: 8
            Text { text: "•"; color: "#55ff55"; font.bold: true }
            Text { text: "Enable MATH submap (Hyprland)"; color: Theme.textPrimary; font.pixelSize: 12 }
        }
        RowLayout {
            spacing: 8
            Text { text: "•"; color: "#55ff55"; font.bold: true }
            Text { text: "Start focus music (MPV)"; color: Theme.textPrimary; font.pixelSize: 12 }
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
            color: Theme.bgSubtle
            border.color: Theme.borderSubtle
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
                    text: MathState.lastSessionDate ? "Last: " + mathPage.formatMathSessionDate(MathState.lastSessionDate) : "No history yet"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: 16
            color: Theme.bgSubtle
            border.color: Theme.borderSubtle
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
            color: Theme.bgSubtle
            border.color: Theme.borderSubtle
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
            color: Theme.bgSubtle
            border.color: Theme.borderSubtle
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
        color: Theme.bgSubtle
        border.color: Theme.borderSubtle
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
                    text: "Recent Days"
                    color: Theme.textPrimary
                    font { pixelSize: 14; bold: true }
                    Layout.fillWidth: true
                }

                AppText {
                    text: MathState.recentSessions.length > 0 ? MathState.recentSessions.length + " days" : "Waiting for data"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
            }

            AppText {
                Layout.fillWidth: true
                text: MathState.lastSessionDate ? "Last session: " + mathPage.formatMathSessionDate(MathState.lastSessionDate) : "Complete one session to unlock the chart."
                color: Theme.textSecondary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Item {
                visible: MathState.recentSessions.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 178

                id: mathLineChart
                property int hoverIndex: -1
                property real chartLeft: 28
                property real chartRight: 28
                property real chartTop: 28
                property real chartBottom: 42

                function chartSessions() {
                    return MathState.recentSessions || [];
                }

                function pointX(pointIndex) {
                    let sessions = chartSessions();
                    if (sessions.length <= 1)
                        return width / 2;

                    return chartLeft + (pointIndex / (sessions.length - 1)) * Math.max(1, width - chartLeft - chartRight);
                }

                function pointY(chars) {
                    let value = Number(chars);
                    if (isNaN(value))
                        value = 0;

                    let ratio = Math.max(0, Math.min(1, value / mathPage.mathSessionMaxChars()));
                    return chartTop + (1 - ratio) * Math.max(1, height - chartTop - chartBottom);
                }

                function hoveredSession() {
                    let sessions = chartSessions();
                    return hoverIndex >= 0 && hoverIndex < sessions.length ? sessions[hoverIndex] : null;
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Canvas {
                    id: mathLineCanvas
                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        let ctx = getContext("2d");
                        let sessions = MathState.recentSessions || [];

                        ctx.clearRect(0, 0, width, height);

                        if (sessions.length === 0)
                            return;

                        ctx.lineWidth = 1;
                        ctx.strokeStyle = "rgba(255,255,255,0.07)";

                        for (let gridIndex = 0; gridIndex < 3; ++gridIndex) {
                            let gridY = mathLineChart.chartTop + gridIndex * ((height - mathLineChart.chartTop - mathLineChart.chartBottom) / 2);
                            ctx.beginPath();
                            ctx.moveTo(mathLineChart.chartLeft, gridY);
                            ctx.lineTo(width - mathLineChart.chartRight, gridY);
                            ctx.stroke();
                        }

                        if (sessions.length === 1) {
                            let onlySession = sessions[0] || {};
                            let onlyY = mathLineChart.pointY(onlySession.chars !== undefined ? onlySession.chars : 0);

                            ctx.beginPath();
                            ctx.moveTo(mathLineChart.chartLeft, onlyY);
                            ctx.lineTo(width - mathLineChart.chartRight, onlyY);
                            ctx.strokeStyle = "rgba(85,200,255,0.45)";
                            ctx.lineWidth = 3;
                            ctx.lineCap = "round";
                            ctx.stroke();
                            return;
                        }

                        let gradient = ctx.createLinearGradient(0, mathLineChart.chartTop, 0, height - mathLineChart.chartBottom);
                        gradient.addColorStop(0, "rgba(85,200,255,0.22)");
                        gradient.addColorStop(1, "rgba(85,200,255,0.00)");

                        ctx.beginPath();
                        for (let i = 0; i < sessions.length; ++i) {
                            let session = sessions[i] || {};
                            let x = mathLineChart.pointX(i);
                            let y = mathLineChart.pointY(session.chars !== undefined ? session.chars : 0);

                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }

                        ctx.lineTo(mathLineChart.pointX(sessions.length - 1), height - mathLineChart.chartBottom);
                        ctx.lineTo(mathLineChart.pointX(0), height - mathLineChart.chartBottom);
                        ctx.closePath();
                        ctx.fillStyle = gradient;
                        ctx.fill();

                        ctx.beginPath();
                        for (let lineIndex = 0; lineIndex < sessions.length; ++lineIndex) {
                            let lineSession = sessions[lineIndex] || {};
                            let lineX = mathLineChart.pointX(lineIndex);
                            let lineY = mathLineChart.pointY(lineSession.chars !== undefined ? lineSession.chars : 0);

                            if (lineIndex === 0)
                                ctx.moveTo(lineX, lineY);
                            else
                                ctx.lineTo(lineX, lineY);
                        }

                        ctx.strokeStyle = "#55c8ff";
                        ctx.lineWidth = 3;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.stroke();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Connections {
                    target: MathState
                    function onRecentSessionsChanged() {
                        mathLineCanvas.requestPaint();
                    }
                }

                Repeater {
                    model: MathState.recentSessions

                    delegate: Item {
                        width: 34
                        height: 34
                        x: mathLineChart.pointX(index) - width / 2
                        y: mathLineChart.pointY(sessionChars) - height / 2
                        z: 3

                        property var sessionData: modelData
                        property real sessionChars: Number(sessionData && sessionData.chars !== undefined ? sessionData.chars : 0)
                        property int sessionFormulas: Number(sessionData && sessionData.formulas !== undefined ? sessionData.formulas : 0)
                        property int sessionCount: Number(sessionData && sessionData.sessions !== undefined ? sessionData.sessions : 1)
                        property bool isLatest: index === MathState.recentSessions.length - 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: pointMouse.containsMouse ? 18 : 12
                            height: width
                            radius: width / 2
                            color: isLatest ? Theme.info : "#55c8ff"
                            border.color: Theme.textPrimary
                            border.width: pointMouse.containsMouse ? 2 : 0
                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        }

                        MouseArea {
                            id: pointMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: mathLineChart.hoverIndex = index
                            onExited: {
                                if (mathLineChart.hoverIndex === index)
                                    mathLineChart.hoverIndex = -1;
                            }
                        }
                    }
                }

                Repeater {
                    model: MathState.recentSessions

                    delegate: AppText {
                        width: 54
                        x: mathLineChart.pointX(index) - width / 2
                        y: mathLineChart.height - mathLineChart.chartBottom + 12
                        text: mathPage.formatMathSessionDate(modelData && modelData.date ? modelData.date : "")
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    id: mathPointTooltip
                    visible: mathLineChart.hoverIndex >= 0
                    z: 10
                    width: 184
                    height: mathPointTooltipLayout.implicitHeight + 20
                    radius: 14
                    color: Qt.rgba(0.05, 0.05, 0.05, 0.94)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    x: Math.max(0, Math.min(parent.width - width, mathLineChart.pointX(mathLineChart.hoverIndex) - width / 2))
                    y: Math.max(0, mathLineChart.pointY(pointChars) - height - 10)

                    property var pointData: mathLineChart.hoveredSession()
                    property int pointChars: Number(pointData && pointData.chars !== undefined ? pointData.chars : 0)
                    property int pointFormulas: Number(pointData && pointData.formulas !== undefined ? pointData.formulas : 0)
                    property int pointSessions: Number(pointData && pointData.sessions !== undefined ? pointData.sessions : 1)

                    ColumnLayout {
                        id: mathPointTooltipLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        AppText {
                            Layout.fillWidth: true
                            text: mathPage.formatMathSessionDate(mathPointTooltip.pointData && mathPointTooltip.pointData.date ? mathPointTooltip.pointData.date : "")
                            color: Theme.textPrimary
                            font { pixelSize: 13; bold: true }
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: mathPointTooltip.pointChars + " symbols"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: mathPointTooltip.pointFormulas + " formulas"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: mathPointTooltip.pointSessions + (mathPointTooltip.pointSessions === 1 ? " session" : " sessions")
                            color: Theme.textSecondary
                            font.pixelSize: 11
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
                    mathPage.requestMathDetails();
                    mathPage.requestCloseRequested();
                } else {
                    MathState.startSession()
                    mathPage.requestClose()
                }
            }
        }
    }
    
    Item { Layout.preferredHeight: 4 }
}
