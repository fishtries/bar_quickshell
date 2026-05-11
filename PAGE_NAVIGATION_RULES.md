# Реализация навигации между страницами (Popout Page Transition)

## Правило для будущих агентов
При создании новых модулей или добавлении страниц в существующие окна (Popout), **всегда** используйте стандартный паттерн навигации с индивидуальным размытием (Blur) и изменением прозрачности (Opacity) для каждой страницы, как это реализовано в `ControlCenterPopout`. 

**ЗАПРЕЩАЕТСЯ** использовать глобальные анимации размытия всего попаута (например, `contentBlurAnim`) для скрытия переходов. 
Глобальные заголовки запрещены: заголовки страниц (кнопки "Назад", названия разделов) должны находиться **строго внутри** макетов самих страниц, чтобы они переключались и анимировались вместе с остальным контентом.

## Шаблон реализации

### 1. Контейнер страниц (`pageContainer`)
Все страницы лежат друг на друге (`width: parent.width` или `anchors.fill`). Контейнер плавно меняет высоту (`implicitHeight`) под текущую активную страницу и имеет `clip: true`.

```qml
Item {
    id: pageContainer
    Layout.fillWidth: true
    implicitHeight: root.currentPage === "page2" ? page2.implicitHeight : page1.implicitHeight
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
    }
    
    // ... здесь лежат страницы ...
}
```

### 2. Структура страницы (`Page`)
Каждая страница самостоятельно контролирует свои эффекты. 
Тайминги анимации **должны строго совпадать** (opacity: 250ms OutQuad, blur: 300ms OutQuad). Размытие включается только при `targetBlur > 0` для экономии ресурсов.

```qml
Item {
    id: page1
    width: parent.width
    implicitHeight: pageLayout.implicitHeight
    height: implicitHeight

    property real targetOpacity: root.currentPage === "page1" ? 1.0 : 0.0
    property real targetBlur: root.currentPage === "page1" ? 0.0 : 0.6

    opacity: targetOpacity
    enabled: opacity > 0

    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
    Behavior on targetBlur { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

    layer.enabled: targetBlur > 0
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 150
        blur: page1.targetBlur
    }

    ColumnLayout {
        id: pageLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingDefault

        // Заголовок (Header) ОБЯЗАТЕЛЬНО находится внутри макета страницы
        RowLayout {
            // ... кнопка назад и текст заголовка ...
        }

        // ... контент страницы ...
    }
}
```
