pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var tasks: []
    property string exportBuffer: ""
    property var deleteQueue: []

    function reloadTasks() {
        root.exportBuffer = "";
        exportStatusPendingProcess.running = true;
    }

    function completeTask(uuid) {
        completeTaskProcess.command = ["task", "rc.data.location=/home/fish/.task", "rc.confirmation=off", uuid, "done"];
        completeTaskProcess.running = true;
    }

    function deleteTask(uuid) {
        deleteTaskProcess.command = ["task", "rc.data.location=/home/fish/.task", "rc.confirmation=off", uuid, "delete"];
        deleteTaskProcess.running = true;
    }

    function deleteTasks(uuids) {
        if (!uuids || uuids.length === 0)
            return;

        let uniqueUuids = [];
        let seen = {};

        for (let i = 0; i < uuids.length; i++) {
            let uuid = uuids[i];

            if (!uuid || seen[uuid])
                continue;

            seen[uuid] = true;
            uniqueUuids.push(uuid);
        }

        if (uniqueUuids.length === 0)
            return;

        root.deleteQueue = uniqueUuids;
        runNextQueuedDelete();
    }

    function runNextQueuedDelete() {
        if (!root.deleteQueue || root.deleteQueue.length === 0) {
            reloadTasks();
            return;
        }

        deleteTasksProcess.command = ["task", "rc.data.location=/home/fish/.task", "rc.confirmation=off", root.deleteQueue[0], "delete"];
        deleteTasksProcess.running = true;
    }

    function addTask(text, project, due) {
        let command = ["task", "rc.data.location=/home/fish/.task", "add"];
        let trimmedProject = project ? project.trim() : "";
        let trimmedDue = due ? due.trim() : "";

        if (trimmedProject !== "")
            command.push("project:" + trimmedProject);

        if (trimmedDue !== "")
            command.push("due:" + trimmedDue);

        command.push(text);
        addTaskProcess.command = command;
        addTaskProcess.running = true;
    }

    function buildTree(rawTasks) {
        let tree = [];
        let projectMap = {};

        function getOrCreateProject(projectStr) {
            if (!projectStr) return null;
            if (projectMap[projectStr]) return projectMap[projectStr];

            let parts = projectStr.split('.');
            let currentPath = "";
            let parentArr = tree;

            for (let i = 0; i < parts.length; i++) {
                let part = parts[i];
                let isLast = i === parts.length - 1;

                if (i > 0) {
                    currentPath += "." + part;
                } else {
                    currentPath = part;
                }

                if (projectMap[currentPath]) {
                    parentArr = projectMap[currentPath].children;
                } else {
                    let newNode = {
                        name: part,
                        type: "project",
                        fullProject: currentPath,
                        children: []
                    };
                    projectMap[currentPath] = newNode;
                    parentArr.push(newNode);
                    parentArr = newNode.children;
                }
            }

            return projectMap[projectStr];
        }

        for (let i = 0; i < rawTasks.length; i++) {
            let t = rawTasks[i];
            t.type = "task";

            let projNode = getOrCreateProject(t.project);
            if (projNode) {
                projNode.children.push(t);
            } else {
                tree.push(t);
            }
        }

        function assignTaskCount(node) {
            if (!node || node.type !== "project")
                return 0;

            let count = 0;

            for (let i = 0; i < node.children.length; i++) {
                let child = node.children[i];

                if (child.type === "task")
                    count++;
                else
                    count += assignTaskCount(child);
            }

            node.taskCount = count;
            return count;
        }

        for (let i = 0; i < tree.length; i++)
            assignTaskCount(tree[i]);

        return tree;
    }

    Process {
        id: exportStatusPendingProcess
        command: ["task", "rc.data.location=/home/fish/.task", "status:pending", "or", "status:completed", "export"]
        stdout: SplitParser {
            onRead: data => {
                root.exportBuffer += data + "\n";
            }
        }
        onExited: {
            try {
                if (root.exportBuffer.trim() !== "") {
                    let parsedTasks = JSON.parse(root.exportBuffer);
                    root.tasks = root.buildTree(parsedTasks);
                } else {
                    root.tasks = [];
                }
            } catch (e) {
                console.error("TodoState: Failed to parse task export:", e);
            }
            root.exportBuffer = "";
        }
    }

    Process {
        id: completeTaskProcess
        onExited: reloadTasks()
    }

    Process {
        id: deleteTaskProcess
        onExited: reloadTasks()
    }

    Process {
        id: deleteTasksProcess
        onExited: {
            if (root.deleteQueue && root.deleteQueue.length > 0)
                root.deleteQueue = root.deleteQueue.slice(1);

            if (root.deleteQueue && root.deleteQueue.length > 0)
                root.runNextQueuedDelete();
            else
                reloadTasks();
        }
    }

    Process {
        id: addTaskProcess
        onExited: reloadTasks()
    }

    Component.onCompleted: {
        reloadTasks();
    }
}
