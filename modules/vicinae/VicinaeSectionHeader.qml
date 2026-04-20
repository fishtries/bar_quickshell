import QtQuick
import "../../components"
import "../../core"

Item {
    id: root

    property string text: ""

    implicitHeight: 30

    AppText {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.textSecondary
        opacity: 0.9
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
