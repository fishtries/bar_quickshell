import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"

PopoutWrapper {
    id: root
    
    popoutWidth: 300
    
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
            }
            
        }
    }
    
}
