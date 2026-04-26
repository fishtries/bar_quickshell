import QtQuick
import QtQuick.Effects

Item {
    id: root

    default property alias content: contentItem.data
    readonly property alias contentWidth: contentItem.implicitWidth
    readonly property alias contentHeight: contentItem.implicitHeight

    // Дочерние элементы рендерятся здесь.
    // contentItem не привязан к root по размеру — он занимает
    // естественный размер от детей. root считывает его implicitWidth/Height.
    Item {
        id: contentItem
    }

    // Шаг 1: Захватываем контент в текстуру, скрывая оригинал
    ShaderEffectSource {
        id: effectSource
        sourceItem: contentItem
        hideSource: true
        visible: false
    }

    // Шаг 2: Сильное размытие — альфа соседних элементов сливается
    MultiEffect {
        id: blurStep
        source: effectSource
        anchors.fill: parent
        blurEnabled: true
        blurMax: 18
        blur: 1.0
        visible: false
    }

    // Шаг 3: Пороговое маскирование — аналог smoothstep.
    // Используем размытую текстуру как маску для себя же:
    // альфа ниже порога → прозрачность, выше → непрозрачность.
    // Это создаёт эффект слияния (gooey) между близкими элементами.
    MultiEffect {
        source: blurStep
        anchors.fill: parent
        maskEnabled: true
        maskSource: effectSource
        maskThresholdMin: 0.4
        maskThresholdMax: 0.6
    }
}
