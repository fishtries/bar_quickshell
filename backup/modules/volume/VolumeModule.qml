import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    // Внутреннее состояние
    property real volume: 0.5
    property bool isMuted: false
    
    property bool isHovered: hoverArea.containsMouse || slider.hovered || slider.pressed
    
    // Внешние размеры
    implicitWidth: container.width
    implicitHeight: 36
    
    // Запрос текущей громкости раз в секунду или при изменении
    Process {
        id: volumePoller
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim()
                if (text.startsWith("Volume:")) {
                    let parts = text.split(" ")
                    if (parts.length >= 2) {
                        let parsedVolume = parseFloat(parts[1])
                        if (!slider.pressed) {
                            root.volume = parsedVolume
                        }
                    }
                    root.isMuted = text.includes("[MUTED]")
                }
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: volumePoller.running = true
    }
    
    Component.onCompleted: volumePoller.running = true
    
    // Обновление громкости (дебрюнс)
    Process {
        id: setVolumeProcess
        property string targetVol: "0.50"
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetVol]
        onExited: volumePoller.running = true
    }

    Timer {
        id: debounceTimer
        interval: 30
        property real targetValue: 0.0
        onTriggered: {
            setVolumeProcess.targetVol = targetValue.toFixed(2)
            setVolumeProcess.running = true
        }
    }
    
    // Включение/Отключение Mute
    Process {
        id: toggleMuteProcess
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: volumePoller.running = true
    }
    
    // Визуальный контейнер
    Rectangle {
        id: container
        height: 36
        // Если наведен - ширина расширяется влево
        width: root.isHovered ? 200 : 36
        radius: 18
        color: root.isHovered ? Qt.rgba(0.05, 0.05, 0.05, 0.6) : Qt.rgba(0.0, 0.0, 0.0, 0)
        
        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutElastic; easing.amplitude: 0.9; easing.period: 0.7 } }
        Behavior on color { ColorAnimation { duration: 300 } }
        
        clip: true
        
        // Используем Slider как основу, но полностью перерисовываем
        Slider {
            id: slider
            anchors.fill: parent
            
            from: 0.0
            to: 1.0
            value: root.volume
            
            onMoved: {
                debounceTimer.targetValue = slider.value
                debounceTimer.restart()
            }
            
            background: Rectangle {
                id: sliderBg
                implicitWidth: 100
                implicitHeight: 36
                width: slider.availableWidth
                height: slider.availableHeight
                radius: 18
                // Фон ползунка виден только при наведении
                color: root.isHovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 250 } }
                
                // Прогресс (заливка)
                Item {
                    id: fillRect
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    clip: true // Обрезаем внутренний прямоугольник, чтобы конец был прямым
                    
                    // Заливка тоже исчезает
                    opacity: root.isHovered ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    
                    // Внутренний прямоугольник всегда имеет полную ширину фона
                    Rectangle {
                        width: sliderBg.width
                        height: parent.height
                        color: root.isMuted ? "#ff5555" : "#ffffff"
                        radius: 18 // Округляем всё, но маска скроет правый конец
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Иконка внутри ползунка
                Item {
                    anchors.fill: parent
                    
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: root.isHovered ? 12 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Иконки Nerd Font
                        text: root.isMuted ? "" : (root.volume > 0.6 ? "" : (root.volume > 0.3 ? "" : ""))
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        
                        readonly property bool isUnderFill: (1.0 - slider.visualPosition) < (anchors.rightMargin / parent.width) && root.isHovered
                        color: isUnderFill ? "#333333" : (root.isMuted ? "#ff5555" : "#ffffff")
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
            
            // Убираем стандартную ручку
            handle: Item { width: 0; height: 0 }

            // Область для прокрутки колесиком на всем бекграунде
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton // Пропускаем клики к слайдеру
                onWheel: (wheel) => {
                    let newVol = root.volume
                    if (wheel.angleDelta.y > 0) newVol = Math.min(1.0, newVol + 0.05)
                    else newVol = Math.max(0.0, newVol - 0.05)
                    debounceTimer.targetValue = newVol
                    debounceTimer.restart()
                }
            }
        }

        // Область для отслеживания наведения (всегда активна)
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: toggleMuteProcess.running = true
            z: -1 // Под слайдером
        }
    }
}
