import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    
    // Входящие свойства
    property string taskId: ""
    property string taskText: ""
    property bool isCompleted: false

    // Сигналы
    signal toggled(string id)

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 300)
    implicitHeight: Math.max(44, rowLayout.implicitHeight + 12)
    color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    radius: 10
    opacity: root.isCompleted ? 0.5 : 1.0

    // Изменение цвета фона при наведении на саму строку задач
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        // Не перехватываем клик, чтобы дочерние элементы (чекбокс и удаление) могли получать клики
        propagateComposedEvents: true 
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 10

        // Левая часть: CheckBox для выполнения задачи
        Rectangle {
            id: checkbox
            width: 20
            height: 20
            radius: 6
            color: root.isCompleted ? Qt.rgba(0.25, 0.8, 0.45, 0.25) : (checkHoverArea.containsMouse ? Qt.rgba(0.25, 0.8, 0.45, 0.2) : "transparent")
            border.color: root.isCompleted ? Qt.rgba(0.25, 0.8, 0.45, 1) : (checkHoverArea.containsMouse ? Qt.rgba(0.25, 0.8, 0.45, 1) : Qt.rgba(0.7, 0.7, 0.75, 1))
            border.width: 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: Qt.rgba(0.25, 0.8, 0.45, 1)
                visible: root.isCompleted || checkHoverArea.containsMouse
                font.pixelSize: 14
                font.bold: true
            }

            MouseArea {
                id: checkHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled(root.taskId)
            }
        }

        // Центральная часть: текст задачи и индикатор срока
        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.taskText
            color: "#f4f4f5"
            wrapMode: Text.Wrap
            font.pixelSize: 15
            font.strikeout: root.isCompleted
        }
    }
}
