import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

PopoutWrapper {
    id: root
    
    popoutWidth: 600

    property string selectedReminderDateKey: EventsState.dateKey(TimeState.day, TimeState.month, TimeState.year)

    function formatDateHeading(dateStr) {
        let parts = dateStr.split("-");
        if (parts.length !== 3)
            return dateStr;

        let dateObj = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return Qt.formatDate(dateObj, "dddd, d MMMM");
    }

    function reminderCountLabel(count) {
        return count === 1 ? `${count} reminder` : `${count} reminders`;
    }

    function dayCountLabel(count) {
        return count === 1 ? `${count} day` : `${count} days`;
    }

    function formatReminderTime(timeStr) {
        return timeStr && timeStr.length > 0 ? timeStr : "No time";
    }

    function scrollToReminderDate(dateKey) {
        let targetIndex = EventsState.indexOfDateKey(dateKey);
        if (targetIndex >= 0)
            remindersList.positionViewAtIndex(targetIndex, ListView.Beginning);
    }
     
    RowLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.bottomMargin: 20
        Layout.topMargin: 10
        spacing: 24
        
        // --- Левая колонка (Часы + Календарь) ---
        ColumnLayout {
            Layout.preferredWidth: 160
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 24
            
            // ─── Большая цифровая панель ──────────────────────────────────
            ColumnLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 0
                
                AppText {
                    text: TimeState.currentTimeWithSeconds
                    Layout.alignment: Qt.AlignLeft
                    font {
                        pixelSize: 48
                        family: Theme.fontClock
                        weight: Font.Black
                    }
                    color: Theme.textPrimary
                }
                
                AppText {
                    text: Qt.formatDate(new Date(TimeState.year, TimeState.month - 1, TimeState.day), "dddd, d MMMM")
                    Layout.alignment: Qt.AlignLeft
                    font { pixelSize: 14; weight: Font.Medium }
                    color: Theme.info
                    opacity: 0.9
                }
            }
            
            // Разделитель
            Rectangle {
                Layout.preferredWidth: 260
                height: 1
                color: Theme.textPrimary
                opacity: 0.1
            }
            
            // ─── Модуль календаря ────────────────────────────────────────
            CalendarModule {
                id: calendar
                Layout.alignment: Qt.AlignLeft
                Layout.preferredWidth: 260
                onDaySelected: function(dateKey, hasEvents) {
                    root.selectedReminderDateKey = dateKey;

                    if (hasEvents)
                        root.scrollToReminderDate(dateKey);
                }
            }
        }

        // --- Правая колонка (Список всех событий) ---
        Rectangle {
            id: remindersContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                ListView {
                    id: remindersList
                    visible: EventsState.sortedEventsList.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 12
                    boundsBehavior: Flickable.StopAtBounds
                    model: EventsState.sortedEventsList

                    delegate: Item {
                        width: remindersList.width
                        height: sectionColumn.implicitHeight + 12

                        readonly property bool isSelected: modelData.dateStr === root.selectedReminderDateKey

                        Column {
                            id: sectionColumn
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: headerColumn.implicitHeight + 14
                                radius: 12
                                color: isSelected ? Theme.bgHover : Theme.bgActive
                                border.width: isSelected ? 1 : 0
                                border.color: Theme.info

                                Column {
                                    id: headerColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 2

                                    AppText {
                                        width: parent.width
                                        text: root.formatDateHeading(modelData.dateStr)
                                        font { pixelSize: 14; weight: Font.DemiBold }
                                        color: isSelected ? Theme.info : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    AppText {
                                        width: parent.width
                                        text: root.reminderCountLabel(modelData.tasks.length)
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                        opacity: 0.8
                                    }
                                }
                            }

                            Repeater {
                                model: modelData.tasks

                                delegate: Rectangle {
                                    width: sectionColumn.width
                                    height: taskColumn.implicitHeight + 14
                                    radius: 10
                                    color: Theme.bgPanel

                                    Column {
                                        id: taskColumn
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        AppText {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.textPrimary
                                            wrapMode: Text.Wrap
                                        }

                                        AppText {
                                            width: parent.width
                                            text: root.formatReminderTime(modelData.time) + (modelData.list ? ` · ${modelData.list}` : "")
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                            wrapMode: Text.Wrap
                                            opacity: 0.85
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                AppText {
                    visible: EventsState.sortedEventsList.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "No reminders yet"
                    color: Theme.textSecondary
                    opacity: 0.5
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
