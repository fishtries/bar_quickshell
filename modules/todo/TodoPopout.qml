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
    property bool needsKeyboard: root.isOpen && root.creatingTask
    property var collapsedProjects: ({})
    property bool dueEnabled: false
    property var dueDate: new Date()
    property int dueHour: 18
    property int dueMinute: 0
    readonly property string safePrimaryFontFamily: Theme.fontPrimary ? String(Theme.fontPrimary) : ""
    readonly property string safeIconFontFamily: Theme.fontIcon ? String(Theme.fontIcon) : ""
    popoutWidth: 380
    animateContentResize: true
    contentResizeDuration: AnimationConfig.durationQuick
    contentResizeEasingType: AnimationConfig.easingDefaultInOut
    autoClose: !root.creatingTask

    Behavior on viewProgress {
        NumberAnimation { duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultInOut }
    }

    onNeedsKeyboardChanged: {
        if (needsKeyboard) {
            createFocusTimer.stop();
            createFocusTimer.start();
        }
    }

    function pad(value) {
        return value < 10 ? "0" + value : "" + value;
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

        TodoState.deleteTasks(uuids);
    }

    function focusTaskInput() {
        if (!root.isOpen || !root.creatingTask)
            return;

        taskInput.forceActiveFocus();
        taskInput.cursorPosition = taskInput.text.length;
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

    function adjustDueHour(delta) {
        root.dueHour = (root.dueHour + delta + 24) % 24;
        root.dueEnabled = true;
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
        root.dueEnabled = true;
        root.dueDate = new Date(root.dueDate.getFullYear(), root.dueDate.getMonth(), root.dueDate.getDate(), root.dueHour, root.dueMinute);
    }

    function setDueFromDateKey(dateKey) {
        let parts = dateKey.split("-");

        if (parts.length !== 3)
            return;

        root.dueDate = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), root.dueHour, root.dueMinute);
        root.dueEnabled = true;
        root.syncCalendarToDueDate();
    }

    function formattedDueLabel() {
        return root.dueEnabled ? Qt.formatDate(root.dueDate, "d MMM yyyy") + " · " + root.pad(root.dueHour) + ":" + root.pad(root.dueMinute) : "No deadline";
    }

    function dueTaskwarriorValue() {
        return root.dueEnabled ? Qt.formatDate(root.dueDate, "yyyy-MM-dd") + "T" + root.pad(root.dueHour) + ":" + root.pad(root.dueMinute) : "";
    }

    function resetTaskForm() {
        taskInput.text = "";
        projectInput.text = "";
        root.dueEnabled = false;
        root.initializeDueSelection();
    }

    function openCreateTask() {
        root.creatingTask = true;
        createFocusTimer.stop();
        createFocusTimer.start();
    }

    function closeCreateTask() {
        createFocusTimer.stop();
        root.creatingTask = false;
        root.resetTaskForm();
    }

    function submitTask() {
        let description = taskInput.text.trim();

        if (description === "")
            return;

        TodoState.addTask(description, projectInput.text, root.dueTaskwarriorValue());
        root.closeCreateTask();
    }

    Timer {
        id: createFocusTimer
        interval: AnimationConfig.durationUltraFast
        repeat: false
        onTriggered: root.focusTaskInput()
    }

    // При открытии попаута (isOpen) - обновляем задачи и устанавливаем фокус в поле ввода
    onIsOpenChanged: {
        if (isOpen) {
            root.creatingTask = false;
            root.resetTaskForm();
            TodoState.reloadTasks();
        } else {
            createFocusTimer.stop();
            root.creatingTask = false;
            root.resetTaskForm();
        }
    }

    // Заголовок
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            visible: root.creatingTask
            implicitWidth: root.creatingTask ? backText.implicitWidth + Theme.spacingDefault * 2 : 0
            implicitHeight: root.creatingTask ? 28 : 0
            radius: 14
            color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: backText
                anchors.centerIn: parent
                text: "Back"
                color: backMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontPrimary
                font.pixelSize: 13
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeCreateTask()
            }
        }
        
        Text {
            text: root.creatingTask ? "New task" : "Tasks"
            color: Theme.textPrimary
            font.family: Theme.fontPrimary
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }
        
        // Кнопка обновления
        Item {
            visible: false
            implicitWidth: 0
            implicitHeight: 0
        }
    }
    
    Rectangle {
        Layout.fillWidth: true
        visible: false
        height: 0
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    // Список/Дерево задач
    Item {
        id: listSection
        Layout.fillWidth: true
        Layout.preferredHeight: sectionHeight
        implicitHeight: sectionHeight
        clip: true

        // ScrollView автоматически увеличивает размер, но ограничивается 500px, чтобы не вылезать за экран
        property real fullHeight: Math.min(500, Math.max(80, taskListLayout.implicitHeight))
        property real sectionHeight: fullHeight * (1 - root.viewProgress)

        Behavior on sectionHeight {
            NumberAnimation { duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultInOut }
        }
        
        ScrollView {
            id: scrollView
            anchors.fill: parent
            opacity: 1 - root.viewProgress
            x: -24 * root.viewProgress
            scale: 1 - 0.03 * root.viewProgress
            transformOrigin: Item.Top
            property real targetBlur: root.viewProgress * 0.6
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            enabled: opacity > 0

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: scrollView.targetBlur
            }

            ColumnLayout {
                id: taskListLayout
                width: scrollView.width
                spacing: 2
                
                // Генерация узлов дерева (либо проект, либо задача из корня)
                Repeater {
                    model: TodoState.tasks
                    delegate: treeNodeDelegate
                }
                
                // Если задач нет
                Item {
                    visible: TodoState.tasks.length === 0
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
    
    Rectangle {
        Layout.fillWidth: true
        visible: false
        height: 0
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    // Поле ввода новой задачи
    Item {
        id: createSection
        Layout.fillWidth: true
        Layout.preferredHeight: sectionHeight
        implicitHeight: sectionHeight
        clip: true

        property real fullHeight: createTaskForm.implicitHeight
        property real sectionHeight: fullHeight * root.viewProgress

        Behavior on sectionHeight {
            NumberAnimation { duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultInOut }
        }

        FocusScope {
            id: createTaskScope
            width: parent.width
            height: createTaskForm.implicitHeight
            focus: root.creatingTask
            opacity: root.viewProgress
            x: 24 * (1 - root.viewProgress)
            scale: 0.97 + 0.03 * root.viewProgress
            enabled: root.creatingTask
            property real targetBlur: (1 - root.viewProgress) * 0.6

            layer.enabled: targetBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 150
                blur: createTaskScope.targetBlur
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
                    implicitHeight: 40
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: root.dueEnabled ? Theme.info : "transparent"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "Deadline"
                            color: Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.formattedDueLabel()
                            color: root.dueEnabled ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: root.dueEnabled
                            implicitWidth: clearDeadlineText.implicitWidth + Theme.spacingDefault * 2
                            implicitHeight: 26
                            radius: 13
                            color: clearDeadlineMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"

                            Text {
                                id: clearDeadlineText
                                anchors.centerIn: parent
                                text: "Clear"
                                color: clearDeadlineMouse.containsMouse ? Theme.error : Theme.textSecondary
                                font.family: Theme.fontPrimary
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: clearDeadlineMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dueEnabled = false
                            }
                        }
                    }
                }

                CalendarModule {
                    id: dueCalendar
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 260
                    onDaySelected: function(dateKey, hasEvents) {
                        root.setDueFromDateKey(dateKey);
                    }
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

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: hourDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: hourDownMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustDueHour(-1)
                        }
                    }

                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 32
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: root.pad(root.dueHour)
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: hourUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: hourUpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustDueHour(1)
                        }
                    }

                    Text {
                        text: ":"
                        color: Theme.textSecondary
                        font.family: Theme.fontPrimary
                        font.pixelSize: 16
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: minuteDownMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: minuteDownMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustDueMinute(-5)
                        }
                    }

                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 32
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: root.pad(root.dueMinute)
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: minuteUpMouse.containsMouse ? Theme.bgHover : Qt.rgba(1, 1, 1, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: Theme.textPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: 16
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

    // Рекурсивный компонент для отрисовки дерева задач
    Component {
        id: treeNodeDelegate
        
        ColumnLayout {
            id: elementRoot
            Layout.fillWidth: true
            spacing: 2
            
            // Логика получения данных: либо из Repeater напрямую (modelData), либо из Loader (property myNodeData)
            property var nodeData: typeof myNodeData !== "undefined" ? myNodeData : modelData
            property bool projectCollapsed: nodeData && nodeData.type === "project" ? root.isProjectCollapsed(nodeData.fullProject) : false
            property int projectTaskCount: (nodeData && nodeData.type === "project") ? ((nodeData.taskCount !== undefined) ? nodeData.taskCount : root.collectProjectTaskUuids(nodeData).length) : 0

            // ---- Если проект ----
            ColumnLayout {
                visible: nodeData && nodeData.type === "project"
                Layout.fillWidth: true
                spacing: 2

                // Заголовок проекта
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
                            id: deleteProjectText
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
                    implicitHeight: childrenRevealProgress * projectChildrenLayout.implicitHeight
                    clip: true

                    property real childrenRevealProgress: elementRoot.projectCollapsed ? 0 : 1

                    Behavior on childrenRevealProgress {
                        NumberAnimation { duration: AnimationConfig.durationVeryFast; easing.type: AnimationConfig.easingDefaultInOut }
                    }

                    opacity: childrenRevealProgress
                    enabled: childrenRevealProgress > 0

                    ColumnLayout {
                        id: projectChildrenLayout
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        width: parent.width - 12
                        spacing: 2

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
            
            // ---- Если задача ----
            TodoItem {
                visible: nodeData && nodeData.type === "task"
                Layout.fillWidth: true
                
                description: (nodeData && nodeData.type === "task") ? nodeData.description : ""
                uuid: (nodeData && nodeData.type === "task") ? nodeData.uuid : ""
                isDue: (nodeData && nodeData.type === "task") ? (nodeData.due !== undefined) : false
                urgency: (nodeData && nodeData.type === "task" && nodeData.urgency !== undefined) ? parseFloat(nodeData.urgency) : 0.0
                isCompleted: (nodeData && nodeData.type === "task") ? (nodeData.status === "completed") : false
                
                // Прокидываем сигналы до TodoState
                onDoneClicked: function(taskUuid) {
                    TodoState.completeTask(taskUuid);
                }
                onDeleteClicked: function(taskUuid) {
                    TodoState.deleteTask(taskUuid);
                }
            }
        }
    }
}
