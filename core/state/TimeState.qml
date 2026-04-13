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
}
