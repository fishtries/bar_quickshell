pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * EventsState - Singleton for managing Apple Reminders and upcoming deadlines.
 * Synchronized with /home/fish/.config/quickshell/data/events.json
 */
Item {
    id: root

    signal reminderTriggered(var reminder)

    // --- Public State ---
    property bool isReminderActive: false
    property string currentReminderText: ""
    property var activeReminder: null
    property var eventMap: ({})
    property var sortedEventsList: [] // Удобный массив для ListView
    property bool reminderActionBusy: false
    property var suppressedReminders: ({})
    property string lastPresentedReminderId: ""

    // --- Configuration ---
    readonly property string fileUri: "file:///home/fish/.config/quickshell/data/events.json"
    readonly property string filePath: "/home/fish/.config/quickshell/data/events.json"
    readonly property string reminderActionScriptPath: "/home/fish/.config/quickshell/scripts/reminder_action.py"

    // --- Logic ---

    Timer {
        id: syncTimer
        interval: 60000 // 1 minute
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: loadEvents()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: checkUpcoming()
    }

    Process {
        id: reminderActionProcess
        command: []
        onExited: function(exitCode, exitStatus) {
            root.reminderActionBusy = false;
            root.lastPresentedReminderId = "";
            root.loadEvents();
        }
    }

    function loadEvents() {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        let responseText = xhr.responseText ? xhr.responseText.trim() : "";
                        root.eventMap = responseText.length > 0 ? JSON.parse(responseText) : ({});
                        updateSortedList();
                        checkUpcoming();
                    } catch(e) {
                        console.error("[EventsState] Error parsing JSON:", e);
                    }
                }
            }
        };
        xhr.open("GET", root.fileUri, true);
        xhr.send();
    }

    function clearExpiredSuppressions() {
        let nowMs = Date.now();
        let next = ({});

        for (let key in root.suppressedReminders) {
            if (root.suppressedReminders[key] > nowMs)
                next[key] = root.suppressedReminders[key];
        }

        root.suppressedReminders = next;
    }

    function suppressReminder(signature, untilMs) {
        let next = ({});
        for (let key in root.suppressedReminders)
            next[key] = root.suppressedReminders[key];

        next[signature] = untilMs;
        root.suppressedReminders = next;
    }

    function isReminderSuppressed(signature) {
        clearExpiredSuppressions();
        let untilMs = root.suppressedReminders[signature];
        return untilMs !== undefined && untilMs > Date.now();
    }

    function reminderSignature(dateKeyStr, timeStr, title, listName) {
        return `${dateKeyStr}|${timeStr || ""}|${title || ""}|${listName || ""}`;
    }

    function reminderId(dateKeyStr, index, task) {
        return `${reminderSignature(dateKeyStr, task ? task.time : "", task ? task.title : "", task ? task.list : "")}|${index}`;
    }

    function parseReminderDateTime(dateKeyStr, timeStr) {
        if (!dateKeyStr || !timeStr)
            return null;

        let dateParts = dateKeyStr.split("-");
        let timeParts = timeStr.split(":");
        if (dateParts.length !== 3 || timeParts.length !== 2)
            return null;

        return new Date(
            Number(dateParts[0]),
            Number(dateParts[1]) - 1,
            Number(dateParts[2]),
            Number(timeParts[0]),
            Number(timeParts[1]),
            0,
            0
        );
    }

    function formatTime(dateObj) {
        let hours = dateObj.getHours().toString().padStart(2, '0');
        let minutes = dateObj.getMinutes().toString().padStart(2, '0');
        return `${hours}:${minutes}`;
    }

    function formatDateKeyFromDate(dateObj) {
        return dateKey(dateObj.getDate(), dateObj.getMonth() + 1, dateObj.getFullYear());
    }

    function createReminderPayload(dateKeyStr, index, task) {
        return {
            id: reminderId(dateKeyStr, index, task),
            signature: reminderSignature(dateKeyStr, task ? task.time : "", task ? task.title : "", task ? task.list : ""),
            dateKey: dateKeyStr,
            index: index,
            title: task && task.title ? task.title : "Reminder",
            time: task && task.time ? task.time : "",
            list: task && task.list ? task.list : ""
        };
    }

    function findUpcomingReminder() {
        let now = new Date();
        let todayKey = root.dateKey(now.getDate(), now.getMonth() + 1, now.getFullYear());
        let tasks = Array.isArray(root.eventMap[todayKey]) ? root.eventMap[todayKey] : [];
        let candidates = [];

        for (let i = 0; i < tasks.length; i++) {
            let task = tasks[i];
            if (!task || !task.time)
                continue;

            let taskDate = root.parseReminderDateTime(todayKey, task.time);
            if (!taskDate)
                continue;

            let signature = root.reminderSignature(todayKey, task.time, task.title, task.list);
            if (root.isReminderSuppressed(signature))
                continue;

            candidates.push({
                payload: root.createReminderPayload(todayKey, i, task),
                diffMinutes: (taskDate.getTime() - now.getTime()) / 60000,
                time: task.time
            });
        }

        candidates.sort(function(a, b) {
            return a.time.localeCompare(b.time);
        });

        for (let j = 0; j < candidates.length; j++) {
            let candidate = candidates[j];
            if (candidate.diffMinutes <= 0 && candidate.diffMinutes >= -5)
                return candidate.payload;
        }

        return null;
    }

    function checkUpcoming() {
        let reminder = findUpcomingReminder();

        root.activeReminder = reminder;
        root.isReminderActive = reminder !== null;
        root.currentReminderText = reminder ? reminder.title : "";

        if (reminder && root.lastPresentedReminderId !== reminder.id) {
            root.lastPresentedReminderId = reminder.id;
            root.reminderTriggered(reminder);
        } else if (!reminder) {
            root.lastPresentedReminderId = "";
        }
    }

    function runReminderCommand(commandParts) {
        root.reminderActionBusy = true;
        reminderActionProcess.command = commandParts;
        reminderActionProcess.running = true;
    }

    function moveReminder(reminder, targetDateKey, targetTime) {
        if (!reminder || root.reminderActionBusy || !targetDateKey || !targetTime)
            return;

        root.suppressReminder(reminder.signature, Date.now() + 120000);

        let targetSignature = root.reminderSignature(targetDateKey, targetTime, reminder.title, reminder.list);
        let targetDateTime = root.parseReminderDateTime(targetDateKey, targetTime);
        if (targetDateTime)
            root.suppressReminder(targetSignature, targetDateTime.getTime());

        root.runReminderCommand([
            "python",
            root.reminderActionScriptPath,
            "move",
            root.filePath,
            reminder.dateKey,
            reminder.index.toString(),
            reminder.title || "",
            reminder.time || "",
            reminder.list || "",
            targetDateKey,
            targetTime
        ]);
    }

    function snoozeReminder(reminder) {
        if (!reminder || root.reminderActionBusy)
            return;

        let targetDate = new Date();
        targetDate.setSeconds(0, 0);
        targetDate = new Date(targetDate.getTime() + (5 * 60000));
        root.moveReminder(reminder, root.formatDateKeyFromDate(targetDate), root.formatTime(targetDate));
    }

    function remindTomorrow(reminder) {
        if (!reminder || root.reminderActionBusy)
            return;

        let targetDate = root.parseReminderDateTime(reminder.dateKey, reminder.time);
        if (!targetDate)
            return;

        targetDate.setDate(targetDate.getDate() + 1);
        targetDate.setSeconds(0, 0);
        root.moveReminder(reminder, root.formatDateKeyFromDate(targetDate), root.formatTime(targetDate));
    }

    function scheduleReminder(reminder, targetDateObj) {
        if (!reminder || root.reminderActionBusy || !targetDateObj)
            return false;

        let normalizedDate = new Date(targetDateObj.getTime());
        normalizedDate.setSeconds(0, 0);

        if (isNaN(normalizedDate.getTime()) || normalizedDate.getTime() <= Date.now())
            return false;

        root.moveReminder(reminder, root.formatDateKeyFromDate(normalizedDate), root.formatTime(normalizedDate));
        return true;
    }

    function completeReminder(reminder) {
        if (!reminder || root.reminderActionBusy)
            return;

        root.suppressReminder(reminder.signature, Date.now() + 120000);
        root.runReminderCommand([
            "python",
            root.reminderActionScriptPath,
            "complete",
            root.filePath,
            reminder.dateKey,
            reminder.index.toString(),
            reminder.title || "",
            reminder.time || "",
            reminder.list || ""
        ]);
    }

    function updateSortedList() {
        let keys = Object.keys(root.eventMap);
        // Сортируем ключи (даты ГГГГ-ММ-ДД сортируются как строки идеально)
        keys.sort();
        
        let newList = [];
        for (let i = 0; i < keys.length; i++) {
            let k = keys[i];
            let tasks = Array.isArray(root.eventMap[k]) ? root.eventMap[k].slice() : [];
            tasks.sort(function(a, b) {
                let timeA = a && a.time ? a.time : "99:99";
                let timeB = b && b.time ? b.time : "99:99";
                return timeA.localeCompare(timeB);
            });

            if (tasks.length === 0)
                continue;

            newList.push({
                dateStr: k,
                tasks: tasks
            });
        }
        root.sortedEventsList = newList;
    }

    // Helper to format date keys manually if needed by other components
    function dateKey(d, m, y) {
        return `${y}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
    }

    function hasEventsForKey(key) {
        let tasks = root.eventMap[key];
        return Array.isArray(tasks) && tasks.length > 0;
    }

    function hasEventsForDate(d, m, y) {
        return hasEventsForKey(dateKey(d, m, y));
    }

    function indexOfDateKey(key) {
        for (let i = 0; i < root.sortedEventsList.length; i++) {
            if (root.sortedEventsList[i].dateStr === key)
                return i;
        }

        return -1;
    }

    Component.onCompleted: loadEvents()
}
