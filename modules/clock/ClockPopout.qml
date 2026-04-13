import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

PopoutWrapper {
    id: root
    
    popoutWidth: 300
    
    property bool inputFocused: eventInput.activeFocus
    
    function releaseFocus() {
        eventInput.focus = false;
        eventInput.text = "";
    }
    
    Item {
        Layout.fillWidth: true
        implicitHeight: mainLayout.implicitHeight

        // Фоновый MouseArea для снятия фокуса при клике мимо поля ввода
        MouseArea {
            anchors.fill: parent
            z: -1 // Под контентом
            onClicked: root.releaseFocus()
        }
        
        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: 24
            
            // ─── Большая цифровая панель ──────────────────────────────────
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0
                
                AppText {
                    text: TimeState.currentTimeWithSeconds
                    Layout.alignment: Qt.AlignHCenter
                    font {
                        pixelSize: 48
                        family: Theme.fontClock
                        weight: Font.Black
                    }
                    color: Theme.textPrimary
                }
                
                AppText {
                    text: Qt.formatDate(new Date(TimeState.year, TimeState.month - 1, TimeState.day), "dddd, d MMMM")
                    Layout.alignment: Qt.AlignHCenter
                    font { pixelSize: 14; weight: Font.Medium }
                    color: Theme.info
                    opacity: 0.9
                }
            }
            
            // Разделитель
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.textPrimary
                opacity: 0.1
            }
            
            // ─── Модуль календаря ────────────────────────────────────────
            CalendarModule {
                id: calendar
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 260
                
                onSelectedDayChanged: root.refreshEvents()
                onSelectedMonthChanged: root.refreshEvents()
                onSelectedYearChanged: root.refreshEvents()
            }
            
            // Разделитель
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.textPrimary
                opacity: 0.1
            }
            
            // ─── Список событий ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 8
                
                AppText {
                    text: "События на " + calendar.selectedDay + " " + calendar.getMonthName(calendar.selectedMonth, calendar.selectedYear).split(' ')[0]
                    font { pixelSize: 12; weight: Font.Bold }
                    color: Theme.textSecondary
                    Layout.bottomMargin: 4
                }
                
                AppText {
                    visible: root.currentEvents.length === 0
                    text: "Нет событий"
                    font.pixelSize: 13
                    color: Theme.textSecondary
                    opacity: 0.5
                }
                
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    
                    Repeater {
                        model: root.currentEvents
                        
                        delegate: RowLayout {
                            width: parent.width
                            spacing: 8
                            
                            Rectangle {
                                width: 6; height: 6
                                radius: 3
                                color: Theme.info
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            AppText {
                                text: modelData
                                Layout.fillWidth: true
                                font.pixelSize: 13
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                            }
                            
                            // Кнопка удаления
                            Item {
                                width: 20; height: 20
                                AppText {
                                    text: "󰅖"
                                    anchors.centerIn: parent
                                    color: rmHover.hovered ? Theme.error : Theme.textSecondary
                                    font.pixelSize: 14
                                }
                                HoverHandler { id: rmHover }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: EventsState.removeEvent(calendar.selectedDay, calendar.selectedMonth, calendar.selectedYear, index)
                                }
                            }
                        }
                    }
                }
                
                // Ввод нового события
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    height: 32
                    radius: 8
                    color: Theme.bgHover
                    border.width: 1
                    border.color: eventInput.activeFocus ? Theme.info : "transparent"
                    
                    TextInput {
                        id: eventInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.textPrimary
                        font {
                            family: Theme.fontPrimary
                            pixelSize: 13
                        }
                        
                        Text {
                            text: "Добавить напоминание..."
                            color: Theme.textSecondary
                            font: eventInput.font
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !eventInput.text && !eventInput.activeFocus
                        }
                        
                        onAccepted: {
                            if (text.trim() !== "") {
                                EventsState.addEvent(calendar.selectedDay, calendar.selectedMonth, calendar.selectedYear, text);
                                text = "";
                            }
                            eventInput.focus = false;
                        }
                        
                        Keys.onEscapePressed: {
                            eventInput.text = "";
                            eventInput.focus = false;
                        }
                    }
                }
            }
        }
    }
    
    // Окно может менять размер, обновляем данные вручную
    property var currentEvents: []
    
    function refreshEvents() {
        if (!calendar) return;
        currentEvents = EventsState.getEventsForDate(calendar.selectedDay, calendar.selectedMonth, calendar.selectedYear);
    }
    
    Connections {
        target: EventsState
        function onEventsChanged() { root.refreshEvents() }
    }
    
    Component.onCompleted: root.refreshEvents()
}
