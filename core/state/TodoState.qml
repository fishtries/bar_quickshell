pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var todoModel: []
    property var _todos: []
    property string _exportBuffer: ""
    property bool _reloadQueued: false
    property var _deleteQueue: []
    readonly property string _taskDataLocation: "/home/fish/.task"
    readonly property var _taskBaseCommand: ["task", "rc.data.location=" + root._taskDataLocation, "rc.confirmation=off"]

    readonly property Timer _syncTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reloadTodos()
    }

    readonly property Process _exportProcess: Process {
        command: []
        stdout: SplitParser {
            onRead: data => {
                root._exportBuffer += data + "\n";
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                console.error("[TodoState] Failed to export Taskwarrior todos:", exitCode, exitStatus);
            else
                root._applyTaskExport(root._exportBuffer);

            root._exportBuffer = "";

            if (root._reloadQueued) {
                root._reloadQueued = false;
                root.reloadTodos();
            }
        }
    }

    readonly property Process _mutationProcess: Process {
        command: []
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                console.error("[TodoState] Failed to mutate Taskwarrior todos:", exitCode, exitStatus);

            if (root._deleteQueue && root._deleteQueue.length > 0) {
                root._runNextDelete();
                return;
            }

            root.reloadTodos();
        }
    }

    function reloadTodos() {
        if (root._exportProcess.running) {
            root._reloadQueued = true;
            return false;
        }

        root._exportBuffer = "";
        root._exportProcess.command = root._taskBaseCommand.concat(["status:pending", "or", "status:completed", "export"]);
        root._exportProcess.running = true;
        return true;
    }

    function addTodo(text, project, due) {
        let description = text ? String(text).trim() : "";

        if (description === "")
            return false;

        if (root._mutationProcess.running)
            return false;

        let args = ["add"];
        let cleanProject = project ? String(project).trim() : "";
        let cleanDue = due ? String(due).trim() : "";

        if (cleanDue !== "")
            args.push("due:" + cleanDue);

        if (cleanProject !== "")
            args.push("project:" + cleanProject);

        args.push(description);
        root._runTaskCommand(args);
        return true;
    }

    function toggleTodo(uuid) {
        let targetUuid = uuid ? String(uuid) : "";

        if (targetUuid === "")
            return false;

        if (root._mutationProcess.running)
            return false;

        let todo = root._findTodo(targetUuid);

        if (!todo)
            return false;

        if (todo.status === "completed")
            root._runTaskCommand([targetUuid, "modify", "status:pending", "end:"]);
        else
            root._runTaskCommand([targetUuid, "done"]);

        return true;
    }

    function deleteTodo(uuid) {
        let targetUuid = uuid ? String(uuid) : "";

        if (targetUuid === "")
            return false;

        if (root._mutationProcess.running)
            return false;

        root._runTaskCommand([targetUuid, "delete"]);
        return true;
    }

    function deleteTodos(uuids) {
        if (!uuids || uuids.length === 0)
            return false;

        if (root._mutationProcess.running)
            return false;

        let deleteMap = {};
        let uniqueUuids = [];

        for (let i = 0; i < uuids.length; i++) {
            let uuid = uuids[i] ? String(uuids[i]) : "";

            if (uuid !== "" && !deleteMap[uuid]) {
                deleteMap[uuid] = true;
                uniqueUuids.push(uuid);
            }
        }

        if (uniqueUuids.length === 0)
            return false;

        root._deleteQueue = uniqueUuids;
        root._runNextDelete();
        return true;
    }

    function _runTaskCommand(args) {
        root._mutationProcess.command = root._taskBaseCommand.concat(args);
        root._mutationProcess.running = true;
    }

    function _runNextDelete() {
        if (!root._deleteQueue || root._deleteQueue.length === 0) {
            root.reloadTodos();
            return;
        }

        let uuid = root._deleteQueue[0];
        root._deleteQueue = root._deleteQueue.slice(1);
        root._runTaskCommand([uuid, "delete"]);
    }

    function _applyTaskExport(exportText) {
        try {
            let responseText = exportText ? exportText.trim() : "";
            let payload = responseText.length > 0 ? JSON.parse(responseText) : [];
            root._todos = root._normalizeTodos(payload);
            root._syncModel();
        } catch (e) {
            console.error("[TodoState] Failed to parse Taskwarrior export:", e);
            root._todos = [];
            root._syncModel();
        }
    }

    function _normalizeTodos(payload) {
        let source = Array.isArray(payload) ? payload : [];
        let normalized = [];
        let seen = {};

        for (let i = 0; i < source.length; i++) {
            let item = source[i];

            if (!item)
                continue;

            let description = item.description !== undefined && item.description !== null ? String(item.description).trim() : "";

            if (description === "")
                continue;

            let uuid = item.uuid !== undefined && item.uuid !== null ? String(item.uuid).trim() : "";

            if (uuid === "" && item.id !== undefined && item.id !== null)
                uuid = String(item.id).trim();

            if (uuid === "" || seen[uuid])
                continue;

            seen[uuid] = true;
            let status = item.status !== undefined && item.status !== null ? String(item.status) : "pending";

            let todo = {
                uuid: uuid,
                description: description,
                status: status === "completed" ? "completed" : "pending",
                createdAt: item.entry ? String(item.entry) : new Date().toISOString(),
                urgency: item.urgency !== undefined && !isNaN(parseFloat(item.urgency)) ? parseFloat(item.urgency) : 0.0
            };
            let project = item.project !== undefined && item.project !== null ? String(item.project).trim() : "";
            let due = item.due !== undefined && item.due !== null ? String(item.due).trim() : "";

            if (project !== "")
                todo.project = project;

            if (due !== "")
                todo.due = due;

            if (todo.status === "completed" && item.end)
                todo.completedAt = String(item.end);

            normalized.push(todo);
        }

        return normalized;
    }

    function _syncModel() {
        root.todoModel = root._buildTree(root._todos);
    }

    function _buildTree(rawTodos) {
        let tree = [];
        let projectMap = {};

        function getOrCreateProject(projectStr) {
            if (!projectStr)
                return null;

            if (projectMap[projectStr])
                return projectMap[projectStr];

            let parts = projectStr.split(".");
            let currentPath = "";
            let parentArr = tree;

            for (let i = 0; i < parts.length; i++) {
                let part = parts[i];

                if (i > 0)
                    currentPath += "." + part;
                else
                    currentPath = part;

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

        for (let i = 0; i < rawTodos.length; i++) {
            let todo = root._cloneTodo(rawTodos[i]);
            todo.type = "task";

            let projectNode = getOrCreateProject(todo.project);

            if (projectNode)
                projectNode.children.push(todo);
            else
                tree.push(todo);
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

        for (let j = 0; j < tree.length; j++)
            assignTaskCount(tree[j]);

        return tree;
    }

    function _cloneTodo(todo) {
        let clone = {};

        for (let key in todo)
            clone[key] = todo[key];

        return clone;
    }

    function _findTodo(uuid) {
        for (let i = 0; i < root._todos.length; i++) {
            if (root._todos[i].uuid === uuid)
                return root._todos[i];
        }

        return null;
    }
}
