import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

import "../../components"
import "../../core"
import "../../core/state"
import "../clock"

PopoutWrapper {
    id: root

    property bool creatingTask: false
    property real viewProgress: creatingTask ? 1 : 0
    property var collapsedProjects: ({})
    property int dueHour: 18
    property int dueMinute: 0
    property bool dueEnabled: false
    property bool dueTimeEnabled: false
    property var dueDate: new Date()
    readonly property string safePrimaryFontFamily: Theme.fontPrimary ? String(Theme.fontPrimary) : ""
    readonly property string safeIconFontFamily: Theme.fontIcon ? String(Theme.fontIcon) : ""

    popoutWidth: 380
    animateContentResize: false
    contentResizeDuration: 350
    contentResizeEasingType: AnimationConfig.easingDefaultInOut
    autoClose: !root.creatingTask

    SequentialAnimation {
        id: bubbleAnim
        NumberAnimation { target: root; property: "bubbleScale"; to: 1.015; duration: 200; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "bubbleScale"; to: 1.0; duration: 1000; easing.type: Easing.OutElastic; easing.period: 0.4; easing.amplitude: 0.9 }
    }

    onCreatingTaskChanged: {
        if (root.isOpen) {
            bubbleAnim.restart();
        }
    }

    Behavior on viewProgress {
        NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
    }

    function pad(value) {
        return value < 10 ? "0" + value : "" + value;
    }

    function dueValue() {
        if (!root.dueEnabled && !root.dueTimeEnabled)
            return "";

        let dateValue = Qt.formatDate(root.dueDate, "yyyy-MM-dd");
        return root.dueTimeEnabled ? dateValue + "T" + root.pad(root.dueHour) + ":" + root.pad(root.dueMinute) : dateValue;
    }

    function formattedDueLabel() {
        return root.dueEnabled ? Qt.formatDate(root.dueDate, "d MMM yyyy") : "No date";
    }

    function formattedTimeLabel() {
        return root.dueTimeEnabled ? root.pad(root.dueHour) + ":" + root.pad(root.dueMinute) : "No time";
    }

    function toggleDueDate() {
        root.dueEnabled = !root.dueEnabled;

        if (root.dueEnabled)
            root.syncCalendarToDueDate();
    }

    function toggleDueTime() {
        root.dueTimeEnabled = !root.dueTimeEnabled;
    }

    function syncCalendarToDueDate() {
        dueCalendar.selectedDay = root.dueDate.getDate();
        dueCalendar.selectedMonth = root.dueDate.getMonth() + 1;
        dueCalendar.selectedYear = root.dueDate.getFullYear();
        dueCalendar.viewMonth = dueCalendar.selectedMonth;
        dueCalendar.viewYear = dueCalendar.selectedYear;
    }

    function initializeDueSelection() {
        let now = new Date();
        let roundedMinutes = Math.ceil(now.getMinutes() / 5) * 5;
        let initialDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), 0, 0, 0);

        if (roundedMinutes >= 60) {
            initialDate.setHours(initialDate.getHours() + 1);
            roundedMinutes = 0;
        }

        root.dueDate = initialDate;
        root.dueHour = initialDate.getHours();
        root.dueMinute = roundedMinutes;
        root.syncCalendarToDueDate();
    }

    function setDueFromDateKey(dateKey) {
        let parts = dateKey.split("-");

        if (parts.length !== 3)
            return;

        root.dueDate = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), root.dueHour, root.dueMinute);
        root.dueEnabled = true;
        root.syncCalendarToDueDate();
    }

    function adjustDueHour(delta) {
        root.dueHour = (root.dueHour + delta + 24) % 24;
        root.dueTimeEnabled = true;
        root.dueDate = new Date(root.dueDate.getFullYear(), root.dueDate.getMonth(), root.dueDate.getDate(), root.dueHour, root.dueMinute);
    }

    function adjustDueMinute(delta) {
        let total = root.dueHour * 60 + root.dueMinute + delta;

        while (total < 0)
            total += 24 * 60;

        while (total >= 24 * 60)
            total -= 24 * 60;

        root.dueHour = Math.floor(total / 60);
        root.dueMinute = total % 60;
        root.dueTimeEnabled = true;
        root.dueDate = new Date(root.dueDate.getFullYear(), root.dueDate.getMonth(), root.dueDate.getDate(), root.dueHour, root.dueMinute);
    }

    function isProjectCollapsed(projectPath) {
        return projectPath ? !!root.collapsedProjects[projectPath] : false;
    }

    function toggleProjectCollapsed(projectPath) {
        if (!projectPath)
            return;

        let nextState = {};

        for (let key in root.collapsedProjects)
            nextState[key] = root.collapsedProjects[key];

        if (nextState[projectPath])
            delete nextState[projectPath];
        else
            nextState[projectPath] = true;

        root.collapsedProjects = nextState;
    }

    function collectProjectTaskUuids(node) {
        let uuids = [];

        if (!node)
            return uuids;

        if (node.type === "task") {
            if (node.uuid)
                uuids.push(node.uuid);

            return uuids;
        }

        if (!node.children)
            return uuids;

        for (let i = 0; i < node.children.length; i++)
            uuids = uuids.concat(root.collectProjectTaskUuids(node.children[i]));

        return uuids;
    }

    function projectDisplayName(node) {
        if (!node || node.name === undefined || node.name === null)
            return "";

        return String(node.name);
    }

    function deleteProject(node) {
        let uuids = root.collectProjectTaskUuids(node);

        if (uuids.length === 0)
            return;

        TodoState.deleteTodos(uuids);
    }

    function openCreateTask() {
        root.creatingTask = true;
        root.initializeDueSelection();
        taskInput.forceActiveFocus();
    }

    function closeCreateTask() {
        root.creatingTask = false;
        root.resetTaskForm();
    }

    function resetTaskForm() {
        taskInput.text = "";
        projectInput.text = "";
        root.dueEnabled = false;
        root.dueTimeEnabled = false;
        root.initializeDueSelection();
    }

    function submitTask() {
        let text = taskInput.text.trim();

        if (text === "")
            return;

        if (TodoState.addTodo(text, projectInput.text, root.dueValue()))
            root.closeCreateTask();
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingDefault
    Item {
        id: pageContainer
        Layout.fillWidth: true
        implicitHeight: root.creatingTask ? createPage.implicitHeight : listPage.implicitHeight
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
        }

        Item {
            id: listPage
            width: parent.width
            implicitHeight: Math.min(500, Math.max(80, taskListLayout.implicitHeight))
            height: implicitHeight

            property real targetOpacity: root.creatingTask ? 0.0 : 1.0
            property real targetBlur: root.creatingTask ? 0.6 : 0.0

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                }
            }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: listPage.targetBlur
            }

            ScrollView {
                id: scrollView
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    id: taskListLayout
                    width: scrollView.width
                    spacing: 2

                    Repeater {
                        model: TodoState.todoModel
                        delegate: treeNodeDelegate
                    }

                    Item {
                        visible: TodoState.todoModel.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 80

                        Text {
                            anchors.centerIn: parent
                            text: "You are all done for now! 󰄱"
                            color: Theme.success
                            font.family: Theme.fontPrimary
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Theme.radiusPanel / 2
                        color: addTaskMouse.containsMouse ? Theme.bgHover : "transparent"
                        border.color: addTaskMouse.containsMouse ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.45) : "transparent"
                        border.width: 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingDefault
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Add task"
                            color: addTaskMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 15
                        }

                        MouseArea {
                            id: addTaskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openCreateTask()
                        }
                    }
                }
            }
        }
            }
        }

        Item {
            id: createPage
            width: parent.width
            implicitHeight: createTaskForm.implicitHeight
            height: implicitHeight

            property real targetOpacity: root.creatingTask ? 1.0 : 0.0
            property real targetBlur: root.creatingTask ? 0.0 : 0.6

            opacity: targetOpacity
            enabled: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                }
            }
            Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: createPage.targetBlur
            }

            ColumnLayout {
                id: createTaskForm
                width: parent.width
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: taskInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                    border.color: taskInput.activeFocus ? Theme.info : "transparent"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: taskInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 14
                        clip: true
                        selectByMouse: true
                        activeFocusOnTab: true

                        Keys.onEscapePressed: root.closeCreateTask()
                        Keys.onReturnPressed: projectInput.forceActiveFocus()
                        Keys.onEnterPressed: projectInput.forceActiveFocus()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Task description"
                            color: Theme.textSecondary
                            font: taskInput.font
                            enabled: false
                            visible: !taskInput.text && !taskInput.preeditText
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: projectInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                    border.color: projectInput.activeFocus ? Theme.info : "transparent"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: projectInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 14
                        clip: true
                        selectByMouse: true
                        activeFocusOnTab: true

                        Keys.onEscapePressed: root.closeCreateTask()
                        Keys.onReturnPressed: root.submitTask()
                        Keys.onEnterPressed: root.submitTask()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Project (optional)"
                            color: Theme.textSecondary
                            font: projectInput.font
                            enabled: false
                            visible: !projectInput.text && !projectInput.preeditText
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.08)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Calendar"
                        color: Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.formattedDueLabel()
                        color: root.dueEnabled ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: calendarToggleText.implicitWidth + 24
                        implicitHeight: 26
                        radius: 13
                        color: calendarToggleMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            id: calendarToggleText
                            anchors.centerIn: parent
                            text: root.dueEnabled ? "Remove date" : "Add date"
                            color: Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: calendarToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDueDate()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.dueEnabled ? dueCalendar.implicitHeight : 0
                    implicitHeight: Layout.preferredHeight
                    visible: implicitHeight > 1
                    enabled: root.dueEnabled
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                    }

                    CalendarModule {
                        id: dueCalendar
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 260
                        opacity: root.dueEnabled ? 1 : 0
                        y: root.dueEnabled ? 0 : -12

                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        onDaySelected: function(dateKey, hasEvents) {
                            root.setDueFromDateKey(dateKey);
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.08)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Time"
                        color: Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 13
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.formattedTimeLabel()
                        color: root.dueTimeEnabled ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: timeToggleText.implicitWidth + 24
                        implicitHeight: 26
                        radius: 13
                        color: timeToggleMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            id: timeToggleText
                            anchors.centerIn: parent
                            text: root.dueTimeEnabled ? "Remove time" : "Add time"
                            color: Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: timeToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDueTime()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.dueTimeEnabled ? timePickerLayout.implicitHeight : 0
                    implicitHeight: Layout.preferredHeight
                    visible: implicitHeight > 1
                    enabled: root.dueTimeEnabled
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                    }

                    RowLayout {
                        id: timePickerLayout
                        width: parent.width
                        spacing: 12
                        opacity: root.dueTimeEnabled ? 1 : 0
                        y: root.dueTimeEnabled ? 0 : -10

                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                        Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.04)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Hour"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: 10
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: hourDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "−"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: hourDownMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustDueHour(-1)
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: root.pad(root.dueHour)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: 26
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: hourUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "+"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: hourUpMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustDueHour(1)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.04)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Minute"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: 10
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: minuteDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "−"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: minuteDownMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustDueMinute(-5)
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: root.pad(root.dueMinute)
                                        color: Theme.textPrimary
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: 26
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: minuteUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.04)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "+"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: minuteUpMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.adjustDueMinute(5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusPanel / 2
                    color: createTaskMouse.containsMouse ? Theme.bgHover : "transparent"
                    border.color: createTaskMouse.containsMouse ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.45) : "transparent"
                    border.width: 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingDefault
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Create task"
                        color: createTaskMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: createTaskMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitTask()
                    }
                }
            }
        }
    }

    }

    Component {
        id: treeNodeDelegate
        
        ColumnLayout {
            id: elementRoot
            Layout.fillWidth: true
            spacing: 2
            
            property var nodeData: typeof myNodeData !== "undefined" ? myNodeData : modelData
            property bool projectCollapsed: nodeData && nodeData.type === "project" ? root.isProjectCollapsed(nodeData.fullProject) : false
            property int projectTaskCount: (nodeData && nodeData.type === "project") ? ((nodeData.taskCount !== undefined) ? nodeData.taskCount : root.collectProjectTaskUuids(nodeData).length) : 0

            ColumnLayout {
                visible: nodeData && nodeData.type === "project"
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        color: projectToggleMouse.containsMouse ? Theme.bgHover : "transparent"
                        border.color: projectToggleMouse.containsMouse ? Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.35) : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: elementRoot.projectCollapsed ? "▸" : "▾"
                                color: Theme.textSecondary
                                font.family: root.safePrimaryFontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                text: root.safeIconFontFamily !== "" ? "" : ""
                                color: Theme.info
                                font.family: root.safeIconFontFamily
                                font.pixelSize: 14
                            }

                            Text {
                                text: root.projectDisplayName(elementRoot.nodeData)
                                color: Theme.info
                                font.family: root.safePrimaryFontFamily
                                font.bold: true
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: String(elementRoot.projectTaskCount)
                                color: Theme.textSecondary
                                font.family: root.safePrimaryFontFamily
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: projectToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleProjectCollapsed(elementRoot.nodeData.fullProject)
                        }
                    }

                    Rectangle {
                        visible: elementRoot.projectTaskCount > 0
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: deleteProjectMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18) : "transparent"
                        border.color: deleteProjectMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.45) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.safeIconFontFamily !== "" ? "󰆴" : ""
                            color: deleteProjectMouse.containsMouse ? Theme.error : Theme.textSecondary
                            font.family: root.safeIconFontFamily
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: deleteProjectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteProject(elementRoot.nodeData)
                        }
                    }
                }
                
                Item {
                    Layout.fillWidth: true
                    implicitHeight: elementRoot.projectCollapsed ? 0 : projectChildrenLayout.implicitHeight
                    visible: implicitHeight > 1 || !elementRoot.projectCollapsed
                    enabled: !elementRoot.projectCollapsed
                    opacity: elementRoot.projectCollapsed ? 0 : 1
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                    }

                    ColumnLayout {
                        id: projectChildrenLayout
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        y: elementRoot.projectCollapsed ? -8 : 0
                        width: parent.width - 12
                        spacing: 2

                        Behavior on y {
                            NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                        }

                        Repeater {
                            model: (elementRoot.nodeData && elementRoot.nodeData.type === "project" && elementRoot.nodeData.children) ? elementRoot.nodeData.children : []
                            delegate: Loader {
                                Layout.fillWidth: true
                                sourceComponent: treeNodeDelegate
                                property var myNodeData: modelData
                            }
                        }
                    }
                }
            }
            
            TodoItem {
                visible: nodeData && nodeData.type === "task"
                Layout.fillWidth: true
                
                description: (nodeData && nodeData.type === "task") ? nodeData.description : ""
                uuid: (nodeData && nodeData.type === "task") ? nodeData.uuid : ""
                isDue: (nodeData && nodeData.type === "task") ? (nodeData.due !== undefined) : false
                urgency: (nodeData && nodeData.type === "task" && nodeData.urgency !== undefined) ? parseFloat(nodeData.urgency) : 0.0
                isCompleted: (nodeData && nodeData.type === "task") ? (nodeData.status === "completed") : false
                
                onDoneClicked: function(taskUuid) {
                    TodoState.toggleTodo(taskUuid);
                }
                onDeleteClicked: function(taskUuid) {
                    TodoState.deleteTodo(taskUuid);
                }
            }
        }
    }
}
