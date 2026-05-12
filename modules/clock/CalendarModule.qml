import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root

    implicitWidth: 260
    implicitHeight: 280
    signal daySelected(string dateKey, bool hasEvents)

    // When independent is true, this instance manages its own local state
    // instead of binding to the TimeState singleton. Used by TodoPopout,
    // ReminderIslandContent, etc. which need a separate calendar view.
    property bool independent: false

    // ─── Local state (used when independent) ─────────────────────────
    property int _viewMonth: TimeState.month
    property int _viewYear: TimeState.year
    property int _selectedDay: TimeState.day
    property int _selectedMonth: TimeState.month
    property int _selectedYear: TimeState.year

    // Public aliases for external access (TodoPopout, ReminderIslandContent)
    property alias selectedDay: root._selectedDay
    property alias selectedMonth: root._selectedMonth
    property alias selectedYear: root._selectedYear
    property alias viewMonth: root._viewMonth
    property alias viewYear: root._viewYear

    // Effective state (delegates to TimeState or local)
    readonly property int effViewMonth: independent ? _viewMonth : TimeState.viewMonth
    readonly property int effViewYear: independent ? _viewYear : TimeState.viewYear
    readonly property int effSelectedDay: independent ? _selectedDay : TimeState.selectedDay
    readonly property int effSelectedMonth: independent ? _selectedMonth : TimeState.selectedMonth
    readonly property int effSelectedYear: independent ? _selectedYear : TimeState.selectedYear

    readonly property string selectedDateKey: EventsState.dateKey(root.effSelectedDay, root.effSelectedMonth, root.effSelectedYear)

    // ─── Independent mode: local model ──────────────────────────────
    ListModel { id: localModel }

    function _rebuildLocalModel() {
        if (!root.independent) return;
        let result = TimeState.generateCalendarArray(root._viewMonth, root._viewYear);
        localModel.clear();
        for (let item of result) localModel.append(item);
    }

    on_ViewMonthChanged: root._rebuildLocalModel()
    on_ViewYearChanged: root._rebuildLocalModel()

    onIndependentChanged: {
        if (root.independent) root._rebuildLocalModel();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // ─── Header: Month & Navigation ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            AppText {
                text: TimeState.getMonthName(root.effViewMonth, root.effViewYear)
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
                            if (root.independent) {
                                if (root._viewMonth === 1) {
                                    root._viewMonth = 12;
                                    root._viewYear--;
                                } else {
                                    root._viewMonth--;
                                }
                            } else {
                                TimeState.prevMonth();
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
                            if (root.independent) {
                                if (root._viewMonth === 12) {
                                    root._viewMonth = 1;
                                    root._viewYear++;
                                } else {
                                    root._viewMonth++;
                                }
                            } else {
                                TimeState.nextMonth();
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
                model: root.independent ? localModel : TimeState.calendarDaysModel

                delegate: Item {
                    width: root.implicitWidth / 7
                    height: 36

                    readonly property bool isToday: model.day === TimeState.day &&
                                                  model.month === TimeState.month &&
                                                  model.year === TimeState.year

                    readonly property bool isSelected: model.day === root.effSelectedDay &&
                                                     model.month === root.effSelectedMonth &&
                                                     model.year === root.effSelectedYear

                    readonly property bool isCurrentMonth: model.month === root.effViewMonth
                    readonly property bool hasEvents: EventsState.hasEventsForDate(model.day, model.month, model.year)


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
                        text: model.day
                        color: (isToday && isSelected) ? "#000000" : (isCurrentMonth ? Theme.textPrimary : Theme.textSecondary)
                        opacity: isCurrentMonth ? 1.0 : 0.3
                        font {
                            pixelSize: 13
                            weight: isToday ? Font.Bold : Font.Normal
                        }
                    }

                    Rectangle {
                        visible: hasEvents
                        width: 4
                        height: 4
                        radius: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        color: isSelected ? Theme.info : Theme.textSecondary
                        opacity: isCurrentMonth ? 0.95 : 0.4
                    }


                    HoverHandler { id: dayHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.independent) {
                                root._selectedDay = model.day;
                                root._selectedMonth = model.month;
                                root._selectedYear = model.year;
                            } else {
                                TimeState.gotoDate(model.day, model.month, model.year);
                            }

                            let dateKey = EventsState.dateKey(model.day, model.month, model.year);
                            root.daySelected(dateKey, EventsState.hasEventsForKey(dateKey));

                            // Если кликнули на день из другого месяца, перелистываем туда
                            if (model.month !== root.effViewMonth) {
                                if (root.independent) {
                                    root._viewMonth = model.month;
                                    root._viewYear = model.year;
                                } else {
                                    TimeState.viewMonth = model.month;
                                    TimeState.viewYear = model.year;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (root.independent) root._rebuildLocalModel();
    }
}
