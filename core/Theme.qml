pragma Singleton
import QtQuick

QtObject {
    id: root

    // Цвета
    property color bgPanel: Qt.rgba(0.05, 0.05, 0.05, 0.15)
    property color bgPopout: Qt.rgba(0, 0, 0, 1)
    property color bgActive: Qt.rgba(0, 0, 0, 0.28)
    property color bgHover: Qt.rgba(1, 1, 1, 0.08)
    
    // Акценты
    property color textPrimary: "#ffffff"
    property color textSecondary: "#aaaaaa"
    property color textDark: "#1f1f1f"
    property color success: "#55ff55"
    property color error: "#ff5555"
    property color warning: "#ffaa00"
    property color info: "#55ccff"

    // Метрики
    property int radiusPanel: 18
    property int radiusPopout: 16
    property int spacingDefault: 12
    property int spacingSmall: 8

    // Шрифты
    property string fontPrimary: "SF Pro Display" // предполагаемый дефолт
    property string fontClock: "MariosBlack"
    property string fontIcon: "JetBrainsMono Nerd Font"
}
