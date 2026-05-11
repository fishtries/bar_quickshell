pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var todoModel: []
    property var _todos: []
    property bool _writeQueued: false
    property string _pendingWriteJson: ""
    readonly property string _fileUri: "file:///home/fish/.config/quickshell/data/todos.json"
    readonly property string _filePath: "/home/fish/.config/quickshell/data/todos.json"
    readonly property string _writeScript: "import pathlib, sys\npath = pathlib.Path(sys.argv[1])\npath.parent.mkdir(parents=True, exist_ok=True)\npath.write_text(sys.argv[2], encoding='utf-8')\n"

    readonly property Process _writer: Process {
        command: []
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                console.error("[TodoState] Failed to write todos:", exitCode, exitStatus);

            if (root._writeQueued) {
                root._writeQueued = false;
                root._runWrite();
            }
        }
    }

    function addTodo(text, project, due) {
        let description = text ? String(text).trim() : "";

        if (description === "")
            return false;

        let todo = {
            uuid: root._createTodoId(),
            description: description,
            status: "pending",
            createdAt: new Date().toISOString(),
            urgency: 0.0
        };
        let cleanProject = project ? String(project).trim() : "";
        let cleanDue = due ? String(due).trim() : "";

        if (cleanProject !== "")
            todo.project = cleanProject;

        if (cleanDue !== "")
            todo.due = cleanDue;

        root._todos = root._todos.concat([todo]);
        root._syncModel();
        root._persistTodos();
        return true;
    }

    function toggleTodo(uuid) {
        let targetUuid = uuid ? String(uuid) : "";

        if (targetUuid === "")
            return false;

        let changed = false;
        let nextTodos = [];

        for (let i = 0; i < root._todos.length; i++) {
            let todo = root._cloneTodo(root._todos[i]);

            if (todo.uuid === targetUuid) {
                changed = true;

                if (todo.status === "completed") {
                    todo.status = "pending";
                    delete todo.completedAt;
                } else {
                    todo.status = "completed";
                    todo.completedAt = new Date().toISOString();
                }
            }

            nextTodos.push(todo);
        }

        if (!changed)
            return false;

        root._todos = nextTodos;
        root._syncModel();
        root._persistTodos();
        return true;
    }

    function deleteTodo(uuid) {
        let targetUuid = uuid ? String(uuid) : "";

        if (targetUuid === "")
            return false;

        let changed = false;
        let nextTodos = [];

        for (let i = 0; i < root._todos.length; i++) {
            if (root._todos[i].uuid === targetUuid) {
                changed = true;
                continue;
            }

            nextTodos.push(root._cloneTodo(root._todos[i]));
        }

        if (!changed)
            return false;

        root._todos = nextTodos;
        root._syncModel();
        root._persistTodos();
        return true;
    }

    function deleteTodos(uuids) {
        if (!uuids || uuids.length === 0)
            return false;

        let deleteMap = {};

        for (let i = 0; i < uuids.length; i++) {
            let uuid = uuids[i] ? String(uuids[i]) : "";

            if (uuid !== "")
                deleteMap[uuid] = true;
        }

        let changed = false;
        let nextTodos = [];

        for (let j = 0; j < root._todos.length; j++) {
            if (deleteMap[root._todos[j].uuid]) {
                changed = true;
                continue;
            }

            nextTodos.push(root._cloneTodo(root._todos[j]));
        }

        if (!changed)
            return false;

        root._todos = nextTodos;
        root._syncModel();
        root._persistTodos();
        return true;
    }

    function _loadTodos() {
        let xhr = new XMLHttpRequest();

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    let responseText = xhr.responseText ? xhr.responseText.trim() : "";
                    let payload = responseText.length > 0 ? JSON.parse(responseText) : [];
                    root._todos = root._normalizeTodos(payload);
                    root._syncModel();
                } catch (e) {
                    console.error("[TodoState] Failed to parse todos:", e);
                    root._todos = [];
                    root._syncModel();
                }
            }
        };

        xhr.open("GET", root._fileUri, true);
        xhr.send();
    }

    function _persistTodos() {
        root._pendingWriteJson = JSON.stringify(root._todos, null, 2) + "\n";

        if (root._writer.running) {
            root._writeQueued = true;
            return;
        }

        root._runWrite();
    }

    function _runWrite() {
        root._writer.command = ["python", "-c", root._writeScript, root._filePath, root._pendingWriteJson];
        root._writer.running = true;
    }

    function _normalizeTodos(payload) {
        let source = Array.isArray(payload) ? payload : ((payload && Array.isArray(payload.todos)) ? payload.todos : []);
        let normalized = [];
        let seen = {};

        for (let i = 0; i < source.length; i++) {
            let item = source[i];

            if (!item)
                continue;

            let description = item.description !== undefined && item.description !== null ? String(item.description).trim() : "";

            if (description === "" && item.text !== undefined && item.text !== null)
                description = String(item.text).trim();

            if (description === "")
                continue;

            let uuid = item.uuid !== undefined && item.uuid !== null ? String(item.uuid).trim() : "";

            if (uuid === "" && item.id !== undefined && item.id !== null)
                uuid = String(item.id).trim();

            while (uuid === "" || seen[uuid])
                uuid = root._createTodoId();

            seen[uuid] = true;

            let todo = {
                uuid: uuid,
                description: description,
                status: item.status === "completed" || item.completed === true ? "completed" : "pending",
                createdAt: item.createdAt ? String(item.createdAt) : new Date().toISOString(),
                urgency: item.urgency !== undefined && !isNaN(parseFloat(item.urgency)) ? parseFloat(item.urgency) : 0.0
            };
            let project = item.project !== undefined && item.project !== null ? String(item.project).trim() : "";
            let due = item.due !== undefined && item.due !== null ? String(item.due).trim() : "";

            if (project !== "")
                todo.project = project;

            if (due !== "")
                todo.due = due;

            if (todo.status === "completed" && item.completedAt)
                todo.completedAt = String(item.completedAt);

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

    function _createTodoId() {
        return "todo-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1000000000).toString(36);
    }

    Component.onCompleted: root._loadTodos()
}
