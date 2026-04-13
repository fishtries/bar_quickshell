pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    property string dataDir: "/home/fish/.config/quickshell/data"
    property string fileUri: dataDir + "/events.json"
    
    // Внутренний словарь: ключ - "YYYY-MM-DD", значение - массив строк
    property var eventMap: ({})
    
    property bool loaded: false

    signal eventsChanged()

    function dateKey(d, m, y) {
        return `${y}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
    }

    function getEventsForDate(d, m, y) {
        let key = dateKey(d, m, y);
        return root.eventMap[key] || [];
    }

    function hasEvents(d, m, y) {
        let events = getEventsForDate(d, m, y);
        return events.length > 0;
    }

    function addEvent(d, m, y, text) {
        if (!text || text.trim() === "") return;
        
        let key = dateKey(d, m, y);
        let curr = root.eventMap[key] || [];
        curr.push(text);
        
        // Создаем новый объект для триггера биндингов
        let newMap = Object.assign({}, root.eventMap);
        newMap[key] = curr;
        root.eventMap = newMap;
        
        saveEvents();
        root.eventsChanged(); 
    }

    function removeEvent(d, m, y, index) {
        let key = dateKey(d, m, y);
        let curr = root.eventMap[key] || [];
        if (index >= 0 && index < curr.length) {
            curr.splice(index, 1);
            
            let newMap = Object.assign({}, root.eventMap);
            if (curr.length === 0) {
                delete newMap[key];
            } else {
                newMap[key] = curr;
            }
            root.eventMap = newMap;
            
            saveEvents();
            root.eventsChanged();
        }
    }

    // ─── Сохранение и загрузка ───────────────────────────────────────

    // Процесс для асинхронной записи
    Process {
        id: saveProcess
    }

    function saveEvents() {
        let jsonStr = JSON.stringify(root.eventMap).replace(/'/g, "'\\''");
        saveProcess.command = ["bash", "-c", `mkdir -p ${root.dataDir} && echo '${jsonStr}' > ${root.fileUri}`];
        saveProcess.running = true;
    }

    function loadEvents() {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        if (xhr.responseText) {
                            root.eventMap = JSON.parse(xhr.responseText);
                        }
                    } catch(e) {
                         console.error("[EventsState] Error parsing JSON:", e); 
                    }
                }
                root.loaded = true;
                root.eventsChanged();
            }
        };
        xhr.open("GET", "file://" + root.fileUri, true);
        xhr.send();
    }

    Component.onCompleted: {
        loadEvents();
    }
}
