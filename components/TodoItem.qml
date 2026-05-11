import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../core"

Rectangle {
    id: root
    
    // Входящие свойства
    property string description: ""
    property string uuid: ""
    property bool isDue: false
    property real urgency: 0.0
    property bool isCompleted: false

    // Сигналы
    signal doneClicked(string taskUuid)
    signal deleteClicked(string taskUuid)

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 300)
    implicitHeight: Math.max(44, rowLayout.implicitHeight + Theme.spacingDefault)
    color: hoverArea.containsMouse ? Theme.bgHover : "transparent"
    radius: Theme.radiusPanel / 2
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
        anchors.leftMargin: Theme.spacingDefault
        anchors.rightMargin: Theme.spacingDefault
        anchors.topMargin: Theme.spacingSmall
        anchors.bottomMargin: Theme.spacingSmall
        spacing: Theme.spacingDefault

        // Левая часть: CheckBox для выполнения задачи
        Rectangle {
            id: checkbox
            width: 20
            height: 20
            radius: 6
            color: root.isCompleted ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.25) : (checkHoverArea.containsMouse ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.2) : "transparent")
            border.color: root.isCompleted ? Theme.success : (checkHoverArea.containsMouse ? Theme.success : Theme.textSecondary)
            border.width: 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: Theme.success
                visible: root.isCompleted || checkHoverArea.containsMouse
                font.pixelSize: 14
                font.bold: true
            }

            MouseArea {
                id: checkHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doneClicked(root.uuid)
            }
        }

        // Центральная часть: текст задачи и индикатор срока
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            AppText {
                Layout.fillWidth: true
                text: root.description
                // Если isDue истинно, подсвечиваем текст красным, иначе стандартным
                color: root.isDue ? Theme.error : Theme.textPrimary
                font.family: Theme.fontPrimary
                wrapMode: Text.Wrap
                font.pixelSize: 15
                font.strikeout: root.isCompleted
            }
            
            // Если есть deadline, добавим маленький текстовый бейдж
            AppText {
                Layout.fillWidth: true
                visible: root.isDue
                text: "★ Deadline / Due"
                color: Theme.error
                font.pixelSize: 11
                opacity: 0.8
            }
        }

        // Правая часть: кнопка удаления (корзина)
        Rectangle {
            width: 28
            height: 28
            radius: width / 2
            color: deleteHoverArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
            Layout.alignment: Qt.AlignVCenter
            
            Text {
                anchors.centerIn: parent
                text: "󰆴" // mdi-delete / trash icon в Nerd Font
                color: deleteHoverArea.containsMouse ? Theme.error : Qt.rgba(Theme.textSecondary.r, Theme.textSecondary.g, Theme.textSecondary.b, 0.5)
                font.family: Theme.fontIcon
                font.pixelSize: 16
            }

            MouseArea {
                id: deleteHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClicked(root.uuid)
            }
        }
    }
}
