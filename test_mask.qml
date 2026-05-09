import QtQuick
import QtQuick.Effects

Item {
    width: 200
    height: 200
    Rectangle {
        id: content
        anchors.fill: parent
        color: "red"
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: 200
                    height: 200
                    gradient: Gradient {
                        GradientStop { position: 0; color: "white" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }
}
