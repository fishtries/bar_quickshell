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

    ClockModule {
        id: clockModule
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: leftGroup.popoutParent
    }

    TodoModule {
        id: todoModule
        anchors.verticalCenter: parent.verticalCenter
        popoutParent: leftGroup.popoutParent
    }

    SystemTrayModule {
        id: sysTray
        anchors.verticalCenter: parent.verticalCenter
    }
}
