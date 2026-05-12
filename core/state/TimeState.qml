pragma Singleton
import QtQuick

Item {
    id: root

    property string currentTime: Qt.formatTime(new Date(), "HH:mm")
    property string currentTimeWithSeconds: Qt.formatTime(new Date(), "HH:mm:ss")

    property int day: parseInt(Qt.formatDate(new Date(), "d"))
    property int month: parseInt(Qt.formatDate(new Date(), "M"))
    property int year: parseInt(Qt.formatDate(new Date(), "yyyy"))
    property string monthName: Qt.formatDate(new Date(), "MMMM")

    // ─── Calendar View State ─────────────────────────────────────────
    property int viewMonth: root.month
    property int viewYear: root.year

    // Selected date (for highlighting / event display)
    property int selectedDay: root.day
    property int selectedMonth: root.month
    property int selectedYear: root.year

    // Calendar grid model
    property alias calendarDaysModel: calendarModel

    // ─── Calendar Public Functions ───────────────────────────────────

    function nextMonth() {
        if (root.viewMonth === 12) {
            root.viewMonth = 1;
            root.viewYear++;
        } else {
            root.viewMonth++;
        }
    }

    function prevMonth() {
        if (root.viewMonth === 1) {
            root.viewMonth = 12;
            root.viewYear--;
        } else {
            root.viewMonth--;
        }
    }

    function gotoDate(d, m, y) {
        root.selectedDay = d;
        root.selectedMonth = m;
        root.selectedYear = y;
    }

    function gotoDateAndView(d, m, y) {
        root.selectedDay = d;
        root.selectedMonth = m;
        root.selectedYear = y;
        root.viewMonth = m;
        root.viewYear = y;
    }

    function getMonthName(m, y) {
        let d = new Date(y, m - 1, 1);
        return Qt.formatDate(d, "MMMM yyyy");
    }

    // Pure utility: returns JS array of {day, month, year} for a 42-cell grid
    function generateCalendarArray(month, year) {
        let result = [];

        let firstDay = new Date(year, month - 1, 1);
        let lastDay = new Date(year, month, 0);

        let startWs = firstDay.getDay();
        if (startWs === 0) startWs = 7;

        let prevMonthLastDay = new Date(year, month - 1, 0);
        for (let i = startWs - 1; i > 0; i--) {
            result.push({
                day: prevMonthLastDay.getDate() - i + 1,
                month: month === 1 ? 12 : month - 1,
                year: month === 1 ? year - 1 : year,
            });
        }

        for (let i = 1; i <= lastDay.getDate(); i++) {
            result.push({ day: i, month: month, year: year });
        }

        let nextDays = 42 - result.length;
        for (let i = 1; i <= nextDays; i++) {
            result.push({
                day: i,
                month: month === 12 ? 1 : month + 1,
                year: month === 12 ? year + 1 : year,
            });
        }

        return result;
    }

    // ─── Calendar Internal ──────────────────────────────────────────

    ListModel { id: calendarModel }

    function generateCalendar() {
        let result = TimeState.generateCalendarArray(root.viewMonth, root.viewYear);
        calendarModel.clear();
        for (let item of result) calendarModel.append(item);
    }

    onViewMonthChanged: root.generateCalendar()
    onViewYearChanged: root.generateCalendar()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            let now = new Date();
            root.currentTime = Qt.formatTime(now, "HH:mm")
            root.currentTimeWithSeconds = Qt.formatTime(now, "HH:mm:ss")

            // Обновляем дату, если наступил новый день
            let d = parseInt(Qt.formatDate(now, "d"));
            if (d !== root.day) {
                root.day = d;
                root.month = parseInt(Qt.formatDate(now, "M"));
                root.year = parseInt(Qt.formatDate(now, "yyyy"));
                root.monthName = Qt.formatDate(now, "MMMM");
            }
        }
    }

    Component.onCompleted: root.generateCalendar()
}
