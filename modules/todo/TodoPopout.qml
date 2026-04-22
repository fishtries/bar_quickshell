import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../components"
import "../../core"
import "../../core/state"

PopoutWrapper {
    id: root
    
    popoutWidth: 380

    // При открытии попаута (isOpen) - обновляем задачи и устанавливаем фокус в поле ввода
    onIsOpenChanged: {
        if (isOpen) {
            TodoState.reloadTasks();
            taskInput.forceActiveFocus();
        }
    }

    // Заголовок
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: ""
            color: Theme.info
            font.family: Theme.fontIcon
            font.pixelSize: 18
        }
        
        Text {
            text: "Tasks"
            color: Theme.textPrimary
            font.family: Theme.fontPrimary
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }
        
        // Кнопка обновления
        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: reloadMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: ""
                color: reloadMouse.containsMouse ? "#ffffff" : Theme.textSecondary
                font.family: Theme.fontIcon
                font.pixelSize: 14
            }
            
            MouseArea {
                id: reloadMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: TodoState.reloadTasks()
            }
        }
    }
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    // Список/Дерево задач
    ScrollView {
        id: scrollView
        Layout.fillWidth: true
        
        // ScrollView автоматически увеличивает размер, но ограничивается 500px, чтобы не вылезать за экран
        Layout.preferredHeight: Math.min(500, Math.max(80, taskListLayout.implicitHeight))
        
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: taskListLayout
            width: scrollView.width
            spacing: 2
            
            // Генерация узлов дерева (либо проект, либо задача из корня)
            Repeater {
                model: TodoState.tasks
                delegate: treeNodeDelegate
            }
            
            // Если задач нет
            Item {
                visible: TodoState.tasks.length === 0
                Layout.fillWidth: true
                implicitHeight: 80
                
                Text {
                    anchors.centerIn: parent
                    text: "You are all done for now! 󰄱"
                    color: Theme.success
                    font.family: Theme.fontPrimary
                    font.pixelSize: 14
                }
            }
        }
    }
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    // Поле ввода новой задачи
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 8
        color: taskInput.activeFocus ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
        border.color: taskInput.activeFocus ? Theme.info : "transparent"
        border.width: 1
        
        Behavior on border.color { ColorAnimation { duration: 150 } }

        TextField {
            id: taskInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            
            placeholderText: "Add a new task (Enter to save)..."
            placeholderTextColor: Theme.textSecondary
            color: Theme.textPrimary
            font.family: Theme.fontPrimary
            font.pixelSize: 14
            
            background: null
            
            // При нажатии Enter отправляем строку в TodoState
            onAccepted: {
                if (text.trim() !== "") {
                    TodoState.addTask(text.trim());
                    text = ""; // Очищаем после добавления
                }
            }
        }
    }

    // Рекурсивный компонент для отрисовки дерева задач
    Component {
        id: treeNodeDelegate
        
        ColumnLayout {
            id: elementRoot
            Layout.fillWidth: true
            spacing: 2
            
            // Логика получения данных: либо из Repeater напрямую (modelData), либо из Loader (property myNodeData)
            property var nodeData: typeof myNodeData !== "undefined" ? myNodeData : modelData

            // ---- Если проект ----
            ColumnLayout {
                visible: nodeData && nodeData.type === "project"
                Layout.fillWidth: true
                spacing: 2

                // Заголовок проекта
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 8
                        
                        Text {
                            text: "" // Иконка папки
                            color: Theme.info
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                        }
                        Text {
                            text: elementRoot.nodeData ? elementRoot.nodeData.name : ""
                            color: Theme.info 
                            font.family: Theme.fontPrimary
                            font.bold: true
                            font.pixelSize: 13
                        }
                    }
                }
                
                // Вложенные элементы проекта
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12 // левый отступ для визуализации вложенности
                    spacing: 2
                    
                    // Рекурсивный вызов этого же компонента
                    Repeater {
                        model: (elementRoot.nodeData && elementRoot.nodeData.type === "project" && elementRoot.nodeData.children) ? elementRoot.nodeData.children : []
                        delegate: Loader {
                            Layout.fillWidth: true
                            sourceComponent: treeNodeDelegate
                            property var myNodeData: modelData // Прокидываем данные для Loader
                        }
                    }
                }
            }
            
            // ---- Если задача ----
            TodoItem {
                visible: nodeData && nodeData.type === "task"
                Layout.fillWidth: true
                
                description: (nodeData && nodeData.type === "task") ? nodeData.description : ""
                uuid: (nodeData && nodeData.type === "task") ? nodeData.uuid : ""
                isDue: (nodeData && nodeData.type === "task") ? (nodeData.due !== undefined) : false
                urgency: (nodeData && nodeData.type === "task" && nodeData.urgency !== undefined) ? parseFloat(nodeData.urgency) : 0.0
                
                // Прокидываем сигналы до TodoState
                onDoneClicked: function(taskUuid) {
                    TodoState.completeTask(taskUuid);
                }
                onDeleteClicked: function(taskUuid) {
                    TodoState.deleteTask(taskUuid);
                }
            }
        }
    }
}
