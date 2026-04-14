pragma Singleton
import QtQuick 2.15

Item {
    id: root

    // Источник правды для напоминаний
    property var remindersData: ({})
    
    // Состояние активного уведомления
    property bool isReminderActive: false
    property string currentReminderText: ""

    signal eventsChanged()

    /**
     * Загрузка данных из локального JSON файла
     */
    function loadReminders() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        root.remindersData = response;
                        root.eventsChanged(); // Сигнал для старых компонентов
                        checkUpcoming();
                    } catch (e) {
                        console.log("EventsState: Error parsing events.json:", e);
                    }
                } else {
                    console.log("EventsState: Failed to load events.json, status:", xhr.status);
                }
            }
        };
        
        // Используем file:/// для доступа к локальной файловой системе
        xhr.open("GET", "file:///home/fish/.config/quickshell/data/events.json");
        xhr.send();
    }

    /**
     * Проверка ближайших задач
     * Активно за 15 минут до и 5 минут после времени задачи
     */
    function checkUpcoming() {
        const now = new Date();
        
        // Форматируем текущую дату в YYYY-MM-DD
        const year = now.getFullYear();
        const month = ("0" + (now.getMonth() + 1)).slice(-2);
        const day = ("0" + now.getDate()).slice(-2);
        const dateStr = year + "-" + month + "-" + day;

        // Текущее время в минутах от начала дня
        const currentMinutes = now.getHours() * 60 + now.getMinutes();
        
        // Получаем задачи на сегодня
        const tasks = root.remindersData[dateStr] || [];
        
        let foundActive = false;
        
        for (let i = 0; i < tasks.length; i++) {
            const task = tasks[i];
            if (!task.time) continue;

            const timeParts = task.time.split(':');
            if (timeParts.length !== 2) continue;
            
            const taskMinutes = parseInt(timeParts[0]) * 60 + parseInt(timeParts[1]);
            const diff = taskMinutes - currentMinutes;

            // Логика триггера: 15 минут до и 5 минут после
            // (diff > 0 — будущее, diff < 0 — прошлое)
            if (diff >= -5 && diff <= 15) {
                root.isReminderActive = true;
                root.currentReminderText = task.title;
                foundActive = true;
                break; // Берем первое подходящее
            }
        }

        if (!foundActive) {
            root.isReminderActive = false;
            root.currentReminderText = "";
        }
    }

    /**
     * Совместимость со старыми компонентами (ClockPopout)
     */
    function getEventsForDate(day, month, year) {
        const d = ("0" + day).slice(-2);
        const m = ("0" + month).slice(-2);
        const dateStr = year + "-" + m + "-" + d;
        const tasks = root.remindersData[dateStr] || [];
        // Старый формат ожидал массив строк для Repeater
        return tasks.map(t => (t.time ? t.time + " - " : "") + t.title);
    }

    // Обновление раз в минуту
    Timer {
        id: refreshTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.loadReminders();
        }
    }

    // Первоначальная загрузка при создании компонента
    Component.onCompleted: {
        root.loadReminders();
    }
}
