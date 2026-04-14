import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property bool isOpen: false
    property int popoutWidth: 280
    Behavior on popoutWidth {
        enabled: root.isOpen
        NumberAnimation { duration: 800; easing.type: Easing.InOutQuint }
    }
    signal closeRequested()
    property bool autoClose: true
    
    HoverHandler {
        id: hover
    }
    
    Timer {
        interval: 5000
        running: root.isOpen && !hover.hovered && root.autoClose
        onTriggered: root.closeRequested()
    }

    default property alias content: contentLayout.data
    
    // Внешние размеры четко зафиксированы по ширине окна
    implicitWidth: root.popoutWidth
    implicitHeight: popoutRect.y + popoutRect.height
    
    // Точка начала анимации по X внутри попаута (по умолчанию по центру)
    property real originX: popoutWidth / 2

    // Масштаб пузыря — можно анимировать из дочерних компонентов
    property real bubbleScale: 1.0

    Rectangle {
        id: popoutRect
        
        width: 0
        height: 0
        radius: 16
        color: Qt.rgba(0.05, 0.05, 0.05, 0.9)
        // Вычисляются через анимацию x
        x: root.originX
        y: 0

        scale: root.bubbleScale
        transformOrigin: Item.Top
        
        // Целевая точка для перемещения кружка к центру попапа
        property real targetCenterY: Math.max(0, (contentColumn.implicitHeight + 32 - 36) / 2)
        
        states: State {
            name: "open"
            when: root.isOpen
            PropertyChanges { target: popoutRect; width: root.popoutWidth; height: contentColumn.implicitHeight + 32; x: 0; y: 0; blurValue: 0 }
            PropertyChanges { target: contentColumn; opacity: 1.0; scale: 1.0 }
        }
        
        transitions: [
            Transition {
                to: "open"
                SequentialAnimation {
                    // Фаза 1: кружок появляется из иконки
                    ParallelAnimation {
                        NumberAnimation { target: popoutRect; property: "width"; to: 36; duration: 10; easing.type: Easing.OutQuad }
                        NumberAnimation { target: popoutRect; property: "height"; to: 36; duration: 10; easing.type: Easing.OutQuad }
                        NumberAnimation { target: popoutRect; property: "x"; to: root.originX - 18; duration: 10; easing.type: Easing.OutQuad }
                    }
                    // Фаза 2: кружок скользит вниз к центру будущего попапа
                    NumberAnimation { target: popoutRect; property: "y"; to: popoutRect.targetCenterY; duration: 80; easing.type: Easing.InOutQuad }
                    // Фаза 3: кружок раскрывается в полноценный попап
                    ParallelAnimation {
                        NumberAnimation { target: popoutRect; property: "width"; duration: 400; easing.type: Easing.OutElastic; easing.amplitude: 0.5; easing.period: 0.9 }
                        NumberAnimation { target: popoutRect; property: "x"; duration: 400; easing.type: Easing.OutElastic; easing.amplitude: 0.5; easing.period: 0.9 }
                        NumberAnimation { target: popoutRect; property: "height"; duration: 400; easing.type: Easing.OutElastic; easing.amplitude: 0.5; easing.period: 0.9 }
                        NumberAnimation { target: popoutRect; property: "y"; duration: 800; easing.type: Easing.OutElastic; easing.amplitude: 0.1; easing.period: 0.7 }
                        NumberAnimation { target: popoutRect; property: "blurValue"; duration: 200; easing.type: Easing.OutQuad }
                        NumberAnimation { target: contentColumn; property: "opacity"; duration: 800; easing.type: Easing.OutQuad }
                        NumberAnimation { target: contentColumn; property: "scale"; duration: 900; easing.type: Easing.OutElastic; easing.amplitude: 0.5; easing.period: 0.4 }
                    }
                }
            },
            Transition {
                from: "open"
                SequentialAnimation {
                    // Фаза 1: контент исчезает, попап сжимается в кружок и поднимается
                    ParallelAnimation {
                        NumberAnimation { target: contentColumn; property: "opacity"; duration: 100; easing.type: Easing.InQuad }
                        NumberAnimation { target: contentColumn; property: "scale"; duration: 150; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "width"; to: 36; duration: 180; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "x"; to: root.originX - 18; duration: 180; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "height"; to: 36; duration: 180; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "y"; to: popoutRect.targetCenterY/3; duration: 180; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "blurValue"; to: 0.8; duration: 150; easing.type: Easing.InQuad }
                    }
                    // Фаза 2: кружок поднимается к иконке
                    NumberAnimation { target: popoutRect; property: "y"; to: 0; duration: 20; easing.type: Easing.InQuad }
                    // Фаза 3: кружок исчезает
                    ParallelAnimation {
                        NumberAnimation { target: popoutRect; property: "y"; to: 0; duration: 20; easing.type: Easing.OutQuad }
                        NumberAnimation { target: popoutRect; property: "width"; duration: 30; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "x"; to: root.originX; duration: 30; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "height"; duration: 100; easing.type: Easing.InQuad }
                        NumberAnimation { target: popoutRect; property: "blurValue"; duration: 100; easing.type: Easing.InQuad }
                    }
                }
            }
        ]
        
        // Эффект блюра при появлении
        property real blurValue: 1.0

        layer.enabled: blurValue > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 50
            blur: popoutRect.blurValue
        }
        
        // Внутренний контейнер с обрезкой для содержимого
        Item {
            anchors.fill: parent
            clip: true
            
            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                opacity: 0.0
                scale: 0.95
                transformOrigin: Item.Top
                
                ColumnLayout {
                    id: contentLayout
                    Layout.fillWidth: true
                    spacing: 12
                }
            }
        }
    }
}
