import QtQuick
import QtQuick.Effects
import "../../core"

Text {
    id: root

    property string lineText: ""
    property bool isActive: false
    property bool isRevealed: false
    property real visualOpacity: 1.0
    property real visualScale: 1.0
    property real blurAmount: isActive ? 0.0 : 0.12
    property real slideOffset: isRevealed ? 0 : 40
    property real revealOpacity: isRevealed ? 1.0 : 0.0

    text: lineText
    color: isActive ? Theme.textPrimary : (lyricHover.hovered ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.88) : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.6))
    opacity: revealOpacity * visualOpacity
    scale: visualScale
    transform: Translate { y: root.slideOffset }
    transformOrigin: Item.Left
    wrapMode: Text.WordWrap

    font {
        pixelSize: isActive ? 18 : 16
        bold: isActive
    }

    Behavior on slideOffset {
        NumberAnimation { duration: 500; easing.type: Easing.OutQuart }
    }

    Behavior on revealOpacity {
        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    HoverHandler {
        id: lyricHover
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        blurEnabled: !root.isActive && root.blurAmount > 0
        blurMax: 24
        blur: root.blurAmount
    }
}
