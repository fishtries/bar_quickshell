import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

PopoutWrapper {
    id: root
    
    popoutWidth: 600
    
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
            }
        }

        // --- Правая колонка (Список всех событий) ---
        Rectangle {
            id: remindersContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            ListView {
                id: remindersList
                anchors.fill: parent
                anchors.margins: 4
                model: EventsState.sortedEventsList
                spacing: 20
                clip: true
                
                // Плавный скролл при изменении контента или программном сдвиге
                Behavior on contentY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                delegate: Column {
                    width: remindersList.width
                    spacing: 10
                    
                    // Заголовок даты
                    AppText {
                        text: modelData.dateStr
                        font { pixelSize: 13; weight: Font.Bold }
                        color: Theme.info
                        opacity: 0.9
                    }

                    // Группа задач на день
                    Repeater {
                        model: modelData.tasks
                        
                        delegate: Rectangle {
                            width: parent.width
                            height: 40
                            radius: 8
                            color: Theme.bgPanel
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12
                                
                                AppText {
                                    text: modelData.time || "00:00"
                                    font { pixelSize: 12; weight: Font.Medium; family: Theme.fontClock }
                                    color: Theme.textSecondary
                                    Layout.preferredWidth: 40
                                }
                                
                                AppText {
                                    text: modelData.title
                                    font.pixelSize: 13
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
