import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../core"

Item {
    id: root

    property bool isOpen: false
    property int popoutWidth: 280
    property bool animateContentResize: false
    property int contentResizeDuration: AnimationConfig.durationQuick
    property int contentResizeEasingType: AnimationConfig.easingDefaultInOut
    property bool isSettled: false
    readonly property real contentHeight: contentColumn.implicitHeight + root.contentPadding * 2
    property real closeLiftY: 0
    property real closeOriginX: originX
    property real closePopoutWidth: popoutWidth
    readonly property real activeOriginX: root.isOpen ? root.originX : root.closeOriginX
    readonly property real activePopoutWidth: root.isOpen ? root.popoutWidth : root.closePopoutWidth
    readonly property bool isPresented: root.isOpen || popoutRect.width > 0 || popoutRect.height > 0
    function syncCloseGeometry() {
        root.closeOriginX = root.originX;
        root.closePopoutWidth = root.popoutWidth;
        let targetCenterY = Math.max(0, (root.contentHeight - root.bubbleDiameter) / 2);
        root.closeLiftY = targetCenterY / 3;
    }
    Connections {
        target: root
        function onIsOpenChanged() {
            if (root.isOpen) {
                root.isStretching = false;
                root.isDetached = false;
                root.isSnappingBack = false;
                root.dragX = 0;
                root.dragY = 0;
                root.followDragX = 0;
                root.followDragY = 0;
                root.animOffsetX = 0;
                root.animOffsetY = 0;
                popoutRect.opacity = 1.0;
                root.syncCloseGeometry();
            } else {
                root.syncCloseGeometry();
                root.isSettled = false;
            }
        }
    }
    Connections {
        target: root
        function onContentHeightChanged() {
            if (root.isOpen)
                root.syncCloseGeometry();
        }
        function onPopoutWidthChanged() {
            if (root.isOpen)
                root.syncCloseGeometry();
        }
        function onOriginXChanged() {
            if (root.isOpen)
                root.syncCloseGeometry();
        }
    }
    Behavior on popoutWidth {
        enabled: root.isOpen
        NumberAnimation { duration: AnimationConfig.durationVerySlow; easing.type: AnimationConfig.easingMovementInOut }
    }
    signal closeRequested()
    signal detachedDrop(real dropX, real dropY)
    property bool autoClose: true

    property bool enableTearOff: false
    property bool isStretching: false
    property bool isDetached: false
    property real dragY: 0
    property real dragX: 0
    property real followDragY: 0
    property real followDragX: 0
    readonly property real tearThreshold: 100

    property bool isSnappingBack: false
    property real animOffsetX: 0
    property real animOffsetY: 0

    NumberAnimation {
        id: snapAnimX
        target: root
        property: "animOffsetX"
        to: 0
        duration: 1500
        easing.type: Easing.OutElastic
        easing.amplitude: 1.0
        easing.period: 0.7
    }
    NumberAnimation {
        id: snapAnimY
        target: root
        property: "animOffsetY"
        to: 0
        duration: 1500
        easing.type: Easing.OutElastic
        easing.amplitude: 1.0
        easing.period: 0.7
    }

    ParallelAnimation {
        id: snapBackAnimation
        NumberAnimation {
            target: root
            property: "dragY"
            to: 0
            duration: AnimationConfig.durationExtraSlow
            easing.type: Easing.OutElastic
            easing.amplitude: 1.0
            easing.period: 0.8
        }
        NumberAnimation {
            target: root
            property: "dragX"
            to: 0
            duration: AnimationConfig.durationVerySlow
            easing.type: Easing.OutElastic
            easing.amplitude: 1.0
            easing.period: 0.4
        }
        onFinished: {
            root.isStretching = false;
            root.isSnappingBack = false;
        }
    }

    Behavior on followDragX {
        enabled: root.isDetached
        NumberAnimation { duration: 920; easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.68 }
    }

    Behavior on followDragY {
        enabled: root.isDetached
        NumberAnimation { duration: 920; easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.68 }
    }

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
    implicitWidth: root.isPresented ? root.activePopoutWidth : 0
    implicitHeight: root.isPresented ? (popoutRect.y + popoutRect.height) : 0
    width: implicitWidth
    height: implicitHeight

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
        Behavior on height {
            enabled: root.isSettled && !root.isStretching && (root.animateContentResize || root.isDetached)
            NumberAnimation {
                duration: root.isDetached ? AnimationConfig.durationModerate : root.contentResizeDuration
                easing.type: root.isDetached ? Easing.OutBack : root.contentResizeEasingType
            }
        }
        radius: Theme.radiusPopout
        color: Theme.bgPopout
        // Вычисляются через анимацию x
        x: root.activeOriginX
        y: 0


        scale: root.bubbleScale
        transformOrigin: Item.Top

        // Целевая точка для перемещения кружка к центру будущего попапа
        property real targetCenterY: Math.max(0, (root.contentHeight - root.bubbleDiameter) / 2)
        property real collapsedX: root.activeOriginX - root.bubbleRadius

        states: State {
            name: "open"
            when: root.isOpen
            PropertyChanges { target: popoutRect; width: root.popoutWidth; height: contentColumn.implicitHeight + root.contentPadding * 2; x: 0; y: 0; opacity: 1.0; blurValue: 0 }
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
                    ScriptAction { script: { root.syncCloseGeometry(); root.isSettled = true } }
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
                            NumberAnimation { target: popoutRect; property: "y"; to: root.closeLiftY; duration: AnimationConfig.durationQuick; easing.type: AnimationConfig.easingDefaultIn }
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
                            NumberAnimation { target: popoutRect; property: "x"; to: root.activeOriginX; duration: AnimationConfig.durationStep; easing.type: AnimationConfig.easingDefaultIn }
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

        // Анимация растворения при отрыве
        ParallelAnimation {
            id: dissolveAnimation
            NumberAnimation { target: popoutRect; property: "blurValue"; to: 1.0; duration: 250; easing.type: Easing.Linear }
            NumberAnimation { target: popoutRect; property: "opacity"; to: 0; duration: 250; easing.type: Easing.Linear }
            onFinished: {
                let dropX = popoutRect.x;
                let dropY = popoutRect.y;
                root.isDetached = false;
                root.isStretching = false;
                root.isSnappingBack = false;
                root.dragX = 0;
                root.dragY = 0;
                root.followDragX = 0;
                root.followDragY = 0;
                root.animOffsetX = 0;
                root.animOffsetY = 0;
                root.closeRequested();
                root.detachedDrop(dropX, dropY);
            }
        }

        // Зона захвата для отрыва попаута
        Item {
            id: tearZone
            height: 30
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.enableTearOff

            DragHandler {
                enabled: root.enableTearOff
                id: tearHandler
                target: null
                onActiveChanged: {
                    if (!active) {
                        if (root.isDetached) {
                            dissolveAnimation.start();
                        } else {
                            root.isSnappingBack = true;
                            snapBackAnimation.start();
                        }
                    }
                }
                onTranslationChanged: {
                    if (tearHandler.active) {
                        root.dragX = tearHandler.translation.x;
                        root.dragY = tearHandler.translation.y;
                        if (root.isDetached) {
                            root.followDragX = root.dragX;
                            root.followDragY = root.dragY;
                        }
                        if (root.isStretching && tearHandler.translation.y > root.tearThreshold) {
                            let fadeBlur = Math.min(1.0, root.dragY / root.tearThreshold);
                            let fadeOpacity = Math.max(0.3, 1.0 - fadeBlur);

                            let targetX = root.width / 2 + translation.x - popoutRect.width / 2;
                            let targetY = root.contentHeight + translation.y - popoutRect.height / 2;

                            let currentX = root.originX - popoutRect.width / 2;
                            let currentY = 0;

                            root.animOffsetX = currentX - targetX;
                            root.animOffsetY = currentY - targetY;
                            root.followDragX = root.dragX;
                            root.followDragY = root.dragY;

                            root.isDetached = true;
                            root.isStretching = false;

                            detachBlurAnim.stop();
                            detachContentOpacityAnim.stop();
                            popoutRect.blurValue = fadeBlur;
                            contentColumn.opacity = fadeOpacity;

                            snapAnimX.start();
                            snapAnimY.start();
                            detachBlurAnim.start();
                            detachContentOpacityAnim.start();
                        }
                        if (!root.isDetached) {
                            root.isStretching = tearHandler.translation.y > 0;
                        }
                    }
                }
            }
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

                transform: Scale {
                    origin.y: 0
                    yScale: root.isStretching ? (1.0 + (root.dragY / root.contentHeight)) : 1.0
                    Behavior on yScale {
                        enabled: !root.isStretching
                        NumberAnimation {
                            duration: AnimationConfig.durationVerySlow
                            easing.type: Easing.OutElastic
                            easing.amplitude: 1.0
                            easing.period: 0.8
                        }
                    }
                }

                ColumnLayout {
                    id: contentLayout
                    Layout.fillWidth: true
                    spacing: Theme.spacingDefault
                }
            }
        }
    }

    Binding {
        target: popoutRect
        property: "width"
        value: root.popoutWidth
        when: root.isOpen && root.isSettled
    }

    Binding {
        target: popoutRect
        property: "height"
        value: root.isStretching ? root.contentHeight + root.dragY : root.contentHeight
        when: root.isOpen && root.isSettled
    }

    Binding {
        target: popoutRect
        property: "x"
        value: root.width / 2 + root.followDragX - popoutRect.width / 2 + root.animOffsetX
        when: root.isOpen && root.isSettled && root.isDetached
    }

    Binding {
        target: popoutRect
        property: "y"
        value: root.contentHeight + root.followDragY - popoutRect.height / 2 + root.animOffsetY
        when: root.isOpen && root.isSettled && root.isDetached
    }

    Binding {
        target: popoutRect
        property: "blurValue"
        value: root.isStretching ? Math.min(1.0, root.dragY / root.tearThreshold) : 0
        when: root.isOpen && root.isSettled && !root.isDetached
        restoreMode: Binding.RestoreNone
    }

    NumberAnimation {
        id: detachBlurAnim
        target: popoutRect
        property: "blurValue"
        to: 0
        duration: 500
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: detachContentOpacityAnim
        target: contentColumn
        property: "opacity"
        to: 1.0
        duration: 500
        easing.type: Easing.OutQuad
    }

    Binding {
        target: contentColumn
        property: "opacity"
        value: root.isStretching ? Math.max(0.3, 1.0 - (root.dragY / root.tearThreshold)) : 1.0
        when: root.isOpen && root.isSettled && !root.isDetached
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: contentColumn
        property: "scale"
        value: 1.0
        when: root.isOpen && root.isSettled
    }
}
