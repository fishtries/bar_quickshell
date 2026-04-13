import QtQuick
import QtQuick.Layouts

// Компактная квадратная кнопка-плитка для Control Center.
// Использование:
//   QuickButton { icon: "\udb80\udcaf"; label: "Bluetooth"; isActive: true; onClicked: ... ; onRightClicked: ... }

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool isActive: false

    signal clicked()
    signal rightClicked()

    implicitWidth: 80
    implicitHeight: 80
    radius: 14
    color: mouse.containsMouse
        ? Qt.rgba(1, 1, 1, isActive ? 0.18 : 0.1)
        : Qt.rgba(1, 1, 1, isActive ? 0.12 : 0.05)

    border.color: isActive ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    scale: mouse.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.icon
            color: root.isActive ? "#ffffff" : "#888888"
            font.pixelSize: 22
            Layout.alignment: Qt.AlignHCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            text: root.label
            color: root.isActive ? "#e0e0e0" : "#666666"
            font.pixelSize: 10
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(event) {
            if (event.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }
}
