import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../components"
import "../../core"
import "../../core/state"

PopoutWrapper {
    id: root

    property bool creatingTask: false
    property var collapsedProjects: ({})
    property int dueHour: 18
    property int dueMinute: 0
    readonly property string safePrimaryFontFamily: Theme.fontPrimary ? String(Theme.fontPrimary) : ""
    readonly property string safeIconFontFamily: Theme.fontIcon ? String(Theme.fontIcon) : ""

    popoutWidth: 380
    animateContentResize: true
    contentResizeDuration: AnimationConfig.durationQuick
    contentResizeEasingType: AnimationConfig.easingDefaultInOut
    autoClose: !root.creatingTask

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

        TodoState.deleteTodos(uuids);
    }

    function openCreateTask() {
        root.creatingTask = true;
        taskInput.forceActiveFocus();
    }

    function closeCreateTask() {
        root.creatingTask = false;
        root.resetTaskForm();
    }

    function resetTaskForm() {
        taskInput.text = "";
        projectInput.text = "";
        dueInput.text = "";
    }

    function submitTask() {
        let text = taskInput.text.trim();

        if (text === "")
            return;

        if (TodoState.addTodo(text, projectInput.text, dueInput.text))
            root.closeCreateTask();
    }

    function suggestedDueValue() {
        let now = new Date();
        return Qt.formatDate(now, "yyyy-MM-dd") + "T" + root.pad(root.dueHour) + ":" + root.pad(root.dueMinute);
    }

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
            Layout.fillWidth: true
            text: root.creatingTask ? "New task" : "Tasks"
            color: Theme.textPrimary
            font.family: Theme.fontPrimary
            font.pixelSize: 16
            font.bold: true
        }
    }

    Item {
        id: listSection
        Layout.fillWidth: true
        Layout.preferredHeight: root.creatingTask ? 0 : Math.min(500, Math.max(80, taskListLayout.implicitHeight))
        implicitHeight: Layout.preferredHeight
        visible: !root.creatingTask
        clip: true

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

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.creatingTask
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
                Keys.onReturnPressed: dueInput.forceActiveFocus()
                Keys.onEnterPressed: dueInput.forceActiveFocus()

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
            color: dueInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
            border.color: dueInput.activeFocus ? Theme.info : "transparent"
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 150 } }

            TextInput {
                id: dueInput
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
                    text: "Deadline (optional, e.g. " + root.suggestedDueValue() + ")"
                    color: Theme.textSecondary
                    font: dueInput.font
                    enabled: false
                    visible: !dueInput.text && !dueInput.preeditText
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
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: AnimationConfig.durationVeryFast; easing.type: AnimationConfig.easingDefaultInOut }
                    }

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
