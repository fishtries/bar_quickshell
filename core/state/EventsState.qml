pragma Singleton
import QtQuick

/**
 * EventsState - Singleton for managing Apple Reminders and upcoming deadlines.
 * Synchronized with /home/fish/.config/quickshell/data/events.json
 */
Item {
    id: root

    // --- Public State ---
    property bool isReminderActive: false
    property string currentReminderText: ""
    property var eventMap: ({})
    property var sortedEventsList: [] // Удобный массив для ListView

    // --- Configuration ---
    readonly property string fileUri: "file:///home/fish/.config/quickshell/data/events.json"

    // --- Logic ---

    Timer {
        id: syncTimer
        interval: 60000 // 1 minute
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: loadEvents()
    }

    function loadEvents() {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        if (xhr.responseText && xhr.responseText.trim().length > 0) {
                            root.eventMap = JSON.parse(xhr.responseText);
                            updateSortedList();
                            checkUpcoming();
                        }
                    } catch(e) {
                        console.error("[EventsState] Error parsing JSON:", e);
                    }
                }
            }
        };
        xhr.open("GET", root.fileUri, true);
        xhr.send();
    }

    function checkUpcoming() {
        let now = new Date();
        
        // Get today key: YYYY-MM-DD
        let year = now.getFullYear();
        let month = (now.getMonth() + 1).toString().padStart(2, '0');
        let day = now.getDate().toString().padStart(2, '0');
        let todayKey = `${year}-${month}-${day}`;
        
        let tasks = root.eventMap[todayKey] || [];
        let activeFound = false;
        let foundText = "";

        for (let i = 0; i < tasks.length; i++) {
            let task = tasks[i];
            if (!task.time) continue;

            // Parse "HH:MM"
            let timeParts = task.time.split(':');
            if (timeParts.length !== 2) continue;
            
            let h = parseInt(timeParts[0]);
            let m = parseInt(timeParts[1]);

            let taskDate = new Date();
            taskDate.setHours(h, m, 0, 0);

            // Calculate difference in minutes
            let diffMinutes = (taskDate.getTime() - now.getTime()) / 60000;

            /**
             * Reminder logic:
             * - Task is in the next 15 minutes (diff <= 15)
             * - Task was in the last 5 minutes (diff >= -5)
             */
            if (diffMinutes <= 15 && diffMinutes >= -5) {
                activeFound = true;
                foundText = task.title;
                break; // Stop at first upcoming reminder
            }
        }

        root.isReminderActive = activeFound;
        root.currentReminderText = foundText;
    }

    function updateSortedList() {
        let keys = Object.keys(root.eventMap);
        // Сортируем ключи (даты ГГГГ-ММ-ДД сортируются как строки идеально)
        keys.sort();
        
        let newList = [];
        for (let i = 0; i < keys.length; i++) {
            let k = keys[i];
            newList.push({
                dateStr: k,
                tasks: root.eventMap[k]
            });
        }
        root.sortedEventsList = newList;
    }

    // Helper to format date keys manually if needed by other components
    function dateKey(d, m, y) {
        return `${y}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
    }

    Component.onCompleted: loadEvents()
}
