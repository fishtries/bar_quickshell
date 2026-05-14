import QtQuick
import "../../modules/clock"
import "../../modules/todo"
import "../../modules/systemtray"

Row {
    id: leftGroup
    spacing: 16

    property alias clockModule: clockModule
    property alias todoModule: todoModule
    property alias sysTray: sysTray

    property Item popoutParent: null
    property real popoutTopY: 0

    ClockModule {
        id: clockModule
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: leftGroup.popoutParent
        popoutTopY: leftGroup.popoutTopY
    }

    TodoModule {
        id: todoModule
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: leftGroup.popoutParent
        popoutTopY: leftGroup.popoutTopY
    }

    SystemTrayModule {
        id: sysTray
        anchors.verticalCenter: parent.verticalCenter
    }
}
