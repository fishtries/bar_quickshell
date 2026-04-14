import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root
    
    implicitWidth: 260
    implicitHeight: 280
    
    // Внутреннее состояние выбранного месяца/года (по умолчанию текущие)
    property int viewMonth: TimeState.month
    property int viewYear: TimeState.year
    
    // Выбранная дата для показа событий
    property int selectedDay: TimeState.day
    property int selectedMonth: TimeState.month
    property int selectedYear: TimeState.year
    
    // Названия месяцев (в QML лучше брать через Qt.formatDate)
    function getMonthName(m, y) {
        let d = new Date(y, m - 1, 1);
        return Qt.formatDate(d, "MMMM yyyy");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // ─── Header: Month & Navigation ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            
            AppText {
                text: getMonthName(root.viewMonth, root.viewYear)
                Layout.fillWidth: true
                font { pixelSize: 16; weight: Font.Bold }
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Row {
                spacing: 4
                
                // Кнопка назад
                Item {
                    width: 28; height: 28
                    AppText { 
                        text: "󰁍" 
                        anchors.centerIn: parent 
                        font.pixelSize: 18
                        color: prevMouse.hovered ? Theme.info : Theme.textSecondary
                    }
                    HoverHandler { id: prevMouse }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.viewMonth === 1) {
                                root.viewMonth = 12;
                                root.viewYear--;
                            } else {
                                root.viewMonth--;
                            }
                        }
                    }
                }

                // Кнопка вперед
                Item {
                    width: 28; height: 28
                    AppText { 
                        text: "󰁔" 
                        anchors.centerIn: parent 
                        font.pixelSize: 18
                        color: nextMouse.hovered ? Theme.info : Theme.textSecondary
                    }
                    HoverHandler { id: nextMouse }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.viewMonth === 12) {
                                root.viewMonth = 1;
                                root.viewYear++;
                            } else {
                                root.viewMonth++;
                            }
                        }
                    }
                }
            }
        }

        // ─── Weekdays Header ─────────────────────────────────────────
        Grid {
            columns: 7
            spacing: 0
            Layout.fillWidth: true
            
            Repeater {
                model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                delegate: AppText {
                    width: root.implicitWidth / 7
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    font { pixelSize: 11; weight: Font.Normal }
                    color: Theme.textSecondary
                    opacity: 0.6
                }
            }
        }

        // ─── Days Grid ───────────────────────────────────────────────
        Grid {
            id: daysGrid
            columns: 7
            spacing: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Repeater {
                model: generateCalendar(root.viewMonth, root.viewYear)
                
                delegate: Item {
                    width: root.implicitWidth / 7
                    height: 36
                    
                    readonly property bool isToday: modelData.day === TimeState.day && 
                                                  modelData.month === TimeState.month && 
                                                  modelData.year === TimeState.year
                    
                    readonly property bool isSelected: modelData.day === root.selectedDay &&
                                                     modelData.month === root.selectedMonth &&
                                                     modelData.year === root.selectedYear
                    
                    readonly property bool isCurrentMonth: modelData.month === root.viewMonth
                    
                    
                    // Фон (подсветка выбранного дня / сегодняшнего)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        radius: 8
                        
                        color: {
                            if (isSelected && isToday) return Theme.info;
                            if (isSelected) return Theme.bgActive;
                            if (isToday) return Theme.bgHover;
                            if (dayHover.hovered) return Theme.bgHover;
                            return "transparent";
                        }
                        
                        // Если выбран не сегодняшний день, добавляем границу
                        border.width: (isSelected && !isToday) ? 1 : 0
                        border.color: Theme.textSecondary
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    AppText {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: (isToday && isSelected) ? "#000000" : (isCurrentMonth ? Theme.textPrimary : Theme.textSecondary)
                        opacity: isCurrentMonth ? 1.0 : 0.3
                        font { 
                            pixelSize: 13
                            weight: isToday ? Font.Bold : Font.Normal 
                        }
                    }


                    HoverHandler { id: dayHover }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selectedDay = modelData.day;
                            root.selectedMonth = modelData.month;
                            root.selectedYear = modelData.year;
                            
                            
                            // Если кликнули на день из другого месяца, перелистываем туда
                            if (modelData.month !== root.viewMonth) {
                                root.viewMonth = modelData.month;
                                root.viewYear = modelData.year;
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── Calendar Logic ────────────────────────────────────────────
    function generateCalendar(month, year) {
        let result = [];
        
        let firstDay = new Date(year, month - 1, 1);
        let lastDay = new Date(year, month, 0);
        
        // В JS getDay() 0 - воскресенье. Переводим в 1 - понедельник
        let startWs = firstDay.getDay(); 
        if (startWs === 0) startWs = 7; 
        
        // Добавляем дни предыдущего месяца
        let prevMonthLastDay = new Date(year, month - 1, 0);
        for (let i = startWs - 1; i > 0; i--) {
            result.push({
                day: prevMonthLastDay.getDate() - i + 1,
                month: month === 1 ? 12 : month - 1,
                year: month === 1 ? year - 1 : year,
            });
        }
        
        // Дни текущего месяца
        for (let i = 1; i <= lastDay.getDate(); i++) {
            result.push({
                day: i,
                month: month,
                year: year,
            });
        }
        
        // Добавляем дни следующего месяца до заполнения сетки (42 ячейки)
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
}
