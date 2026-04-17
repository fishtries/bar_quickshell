import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../core"

Item {
    id: root

    property bool isOpen: false
    property int popoutWidth: 280
    Behavior on popoutWidth {
        enabled: root.isOpen
        NumberAnimation { duration: AnimationConfig.durationVerySlow; easing.type: AnimationConfig.easingMovementInOut }
    }
    signal closeRequested()
    property bool autoClose: true
    
    HoverHandler {
        id: hover
    }
    
    Timer {
        interval: AnimationConfig.timerPopoutAutoClose
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
    property alias maskItem: popoutRect

    readonly property real bubbleRadius: Theme.radiusPanel
    readonly property real bubbleDiameter: bubbleRadius * 2
    readonly property real contentPadding: Theme.radiusPopout

    Rectangle {
        id: popoutRect
        
        width: 0
        height: 0
        radius: Theme.radiusPopout
        color: Theme.bgPopout
        // Вычисляются через анимацию x
        x: root.originX
        y: 0

        scale: root.bubbleScale
        transformOrigin: Item.Top
        
        // Целевая точка для перемещения кружка к центру будущего попапа
        property real targetCenterY: Math.max(0, (contentColumn.implicitHeight + root.contentPadding * 2 - root.bubbleDiameter) / 2)
        property real collapsedX: root.originX - root.bubbleRadius
        property real collapseLiftY: targetCenterY / 3
        
        states: State {
            name: "open"
            when: root.isOpen
            PropertyChanges { target: popoutRect; width: root.popoutWidth; height: contentColumn.implicitHeight + root.contentPadding * 2; x: 0; y: 0; blurValue: 0 }
            PropertyChanges { target: contentColumn; opacity: 1.0; scale: 1.0 }
        }
        
        transitions: [
            Transition {
                to: "open"
                SequentialAnimation {
                    // Фаза 1: кружок появляется из иконки
                    ParallelAnimation {
                        NumberAnimation { target: popoutRect; property: "width"; to: root.bubbleDiameter; duration: AnimationConfig.durationMicro; easing.type: AnimationConfig.easingDefaultOut }
                        NumberAnimation { target: popoutRect; property: "height"; to: root.bubbleDiameter; duration: AnimationConfig.durationMicro; easing.type: AnimationConfig.easingDefaultOut }
                        NumberAnimation { target: popoutRect; property: "x"; to: popoutRect.collapsedX; duration: AnimationConfig.durationMicro; easing.type: AnimationConfig.easingDefaultOut }
                    }
                    // Фаза 2: кружок скользит вниз к центру будущего попапа
                    NumberAnimation { target: popoutRect; property: "y"; to: popoutRect.targetCenterY; duration: AnimationConfig.durationSwift; easing.type: AnimationConfig.easingDefaultInOut }
                    // Фаза 3: кружок раскрывается в полноценный попап
                    ParallelAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: popoutRect; property: "width"; duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudePopout; easing.period: AnimationConfig.springPeriodPopout }
                            NumberAnimation { target: popoutRect; property: "x"; duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudePopout; easing.period: AnimationConfig.springPeriodPopout }
                            NumberAnimation { target: popoutRect; property: "height"; duration: AnimationConfig.durationModerate; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudePopout; easing.period: AnimationConfig.springPeriodPopout }
                            NumberAnimation { target: popoutRect; property: "y"; duration: AnimationConfig.durationVerySlow; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudePopoutY; easing.period: AnimationConfig.springPeriodPopoutY }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: popoutRect; property: "blurValue"; duration: AnimationConfig.durationFast; easing.type: AnimationConfig.easingDefaultOut }
                            NumberAnimation { target: contentColumn; property: "opacity"; duration: AnimationConfig.durationVerySlow; easing.type: AnimationConfig.easingDefaultOut }
                            NumberAnimation { target: contentColumn; property: "scale"; duration: AnimationConfig.durationExtraSlow; easing.type: AnimationConfig.easingSpringOut; easing.amplitude: AnimationConfig.springAmplitudePopout; easing.period: AnimationConfig.springPeriodPopoutScale }
                        }
                    }
                }
            },
            Transition {
                from: "open"
                SequentialAnimation {
                    // Фаза 1: контент исчезает, попап сжимается в кружок и поднимается
                    ParallelAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: contentColumn; property: "opacity"; duration: AnimationConfig.durationUltraFast; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: contentColumn; property: "scale"; duration: AnimationConfig.durationVeryFast; easing.type: AnimationConfig.easingDefaultIn }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: popoutRect; property: "width"; to: root.bubbleDiameter; duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "x"; to: popoutRect.collapsedX; duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "height"; to: root.bubbleDiameter; duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "y"; to: popoutRect.collapseLiftY; duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "blurValue"; to: 0.8; duration: AnimationConfig.durationVeryFast; easing.type: AnimationConfig.easingDefaultIn }
                        }
                    }
                    // Фаза 2: кружок поднимается к иконке
                    NumberAnimation { target: popoutRect; property: "y"; to: 0; duration: AnimationConfig.durationTiny; easing.type: AnimationConfig.easingDefaultIn }
                    // Фаза 3: кружок исчезает
                    ParallelAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: popoutRect; property: "y"; to: 0; duration: AnimationConfig.durationTiny; easing.type: AnimationConfig.easingDefaultOut }
                            NumberAnimation { target: popoutRect; property: "width"; duration: AnimationConfig.durationStep; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "x"; to: root.originX; duration: AnimationConfig.durationStep; easing.type: AnimationConfig.easingDefaultIn }
                            NumberAnimation { target: popoutRect; property: "height"; duration: AnimationConfig.durationUltraFast; easing.type: AnimationConfig.easingDefaultIn }
                        }
                        NumberAnimation { target: popoutRect; property: "blurValue"; duration: AnimationConfig.durationUltraFast; easing.type: AnimationConfig.easingDefaultIn }
                    }
                }
            }
        ]
        
        // Эффект блюра при появлении
        property real blurValue: 1.0

        layer.enabled: blurValue > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: AnimationConfig.blurMaxHeavy
            blur: popoutRect.blurValue
        }
        
        // Внутренний контейнер с обрезкой для содержимого
        Item {
            anchors.fill: parent
            clip: true
            
            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: root.contentPadding
                spacing: Theme.spacingDefault
                
                opacity: 0.0
                scale: 0.95
                transformOrigin: Item.Top
                
                ColumnLayout {
                    id: contentLayout
                    Layout.fillWidth: true
                    spacing: Theme.spacingDefault
                }
            }
        }
    }
}
