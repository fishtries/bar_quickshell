pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var tasks: []
    property string exportBuffer: ""

    function reloadTasks() {
        root.exportBuffer = "";
        exportStatusPendingProcess.running = true;
    }

    function completeTask(uuid) {
        completeTaskProcess.command = ["bash", "-c", "task rc.confirmation=off " + uuid + " done"];
        completeTaskProcess.running = true;
    }

    function deleteTask(uuid) {
        deleteTaskProcess.command = ["bash", "-c", "task rc.confirmation=off " + uuid + " delete"];
        deleteTaskProcess.running = true;
    }

    function addTask(text) {
        addTaskProcess.command = ["bash", "-c", "task add " + text];
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

        return tree;
    }

    Process {
        id: exportStatusPendingProcess
        command: ["bash", "-c", "task export status:pending"]
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
        id: addTaskProcess
        onExited: reloadTasks()
    }

    Component.onCompleted: {
        reloadTasks();
    }
}
