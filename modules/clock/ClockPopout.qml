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
            
            AppText {
                text: "Reminders Placeholder"
                anchors.centerIn: parent
                color: Theme.textSecondary
                opacity: 0.5
                font.pixelSize: 12
            }
        }
    }
}
