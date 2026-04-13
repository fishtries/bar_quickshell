import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"
import "../../core"

Item {
    id: root
    
    // Внутреннее состояние
    property real volume: VolumeState.volume
    property bool isMuted: VolumeState.isMuted
    
    property bool isHovered: hoverArea.containsMouse || slider.hovered || slider.pressed
    
    // Внешние размеры
    implicitWidth: container.width
    implicitHeight: 36
    
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
                VolumeState.setVolume(slider.value)
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
                        color: root.isMuted ? Theme.error : Theme.textPrimary
                        radius: 18 // Округляем всё, но маска скроет правый конец
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Иконка внутри ползунка
                Item {
                    anchors.fill: parent
                    
                    AppIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: root.isHovered ? 12 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        
                        text: root.isMuted ? "" : (root.volume > 0.6 ? "" : (root.volume > 0.3 ? "" : ""))
                        font.pixelSize: 16
                        
                        readonly property bool isUnderFill: (1.0 - slider.visualPosition) < (anchors.rightMargin / parent.width) && root.isHovered
                        color: isUnderFill ? "#333333" : (root.isMuted ? Theme.error : Theme.textPrimary)
                        
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
                    VolumeState.setVolume(newVol)
                }
            }
        }

        // Область для отслеживания наведения (всегда активна)
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: VolumeState.toggleMute()
            z: -1 // Под слайдером
        }
    }
}
